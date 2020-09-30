Using module './Appdynamics.psm1' 

$start_drlicense_time = Get-Date 

$report = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
#$report2 = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))


[boolean]$publisherON = $FALSE

#Remove all jobs
Get-Job | Remove-Job | Out-Null

#$MaxThreads = 40

$jobs = @()

$controller = "https://customer.saas.appdynamics.com"

$auth = Get-AuthorizationHeader -pair "user@customer1:password"

$appdy = [Appdynamics]::new($controller,$auth)

# Time Range for Status as Reporting in minutes
$start_time = (Get-Date).AddMinutes(-5) | ConvertTo-UnixTimestamp

$end_time = Get-Date | ConvertTo-UnixTimestamp # Now




#Analytics
$apiKey = "api-key-from-appdy-analytics"

$accountName = "global_account-name-123456"

$appdy.SetAnalytics($apiKey,$accountName)

$result = $appdy.GetLogin()

#Custom Schema Name
$index = "customer_name_dr_license_v1"

#$schema = '{ "schema" : { "Application" : "string" , "AppID" : "string" , "NodeID" : "string" , "NodeName" : "string" , "MachineName" : "string" , "Tier" : "string" , "LastInstallTime" : "date" , "LastRestartTime" : "date" , "NodeUsingLicence" : "integer" , "NodeLastKnownTierAppConfig" : "string" , "NodeStatusPercentage" : "float" , "NodeStatusLatest" : "string" , "APMAgentPresent" : "string" , "Historical" : "string" , "Unmanaged" : "string" , "Unregistered" : "string" , "DummyNode" : "string" , "ComponentTypeName" : "string" , "ComponentTypeAgentType" : "string" , "ComponentTypeProductType" : "string" , "MachineOSTypeName" : "string" , "MachineAgentPresent" : "string" , "MachineAgentVersion" : "string" , "AppAgentAgentVersion" : "string" , "AppAgentType" : "string" , "AppAgentLatestAgentRuntime" : "string"} }'
#$schema = '{ "schema" : { "Application" : "string" , "AppID" : "string" , "NodeID" : "string" , "NodeName" : "string" , "MachineName" : "string" , "Tier" : "string" , "LastInstallTime" : "date" , "LastRestartTime" : "date" , "NodeUsingLicence" : "integer" , "NodeLastKnownTierAppConfig" : "string" , "APMAgentPresent" : "string" , "Historical" : "string" , "ComponentTypeName" : "string" , "ComponentTypeAgentType" : "string" , "ComponentTypeProductType" : "string" , "MachineOSTypeName" : "string" , "MachineAgentPresent" : "string" , "MachineAgentVersion" : "string" , "AppAgentAgentVersion" : "string" , "AppAgentType" : "string" , "AppAgentLatestAgentRuntime" : "string"} }'
$schema = '{ "schema" : { "ApplicationName" : "string" , "ApplicationId" : "integer" , "nodeId" : "integer" , "nodeName" : "string" , "MachineId" : "integer" , "agentId" : "integer" , "componentId" : "integer" , "componentName" : "string" , "appServerRestartDate" : "date" , "jvmVersion" : "string" , "componentTypeName" : "string" , "productType" : "string" , "App_Status" : "float" , "Machine_Status" : "float" , "AppServer_Agent_Installed" : "string" , "Machine_Agent_Installed" : "string" , "HostName" : "string" , "appAgentVersion" : "string" , "Status" : "string" } }'

#$schema = $schema | ConvertFrom-Json | ConvertTo-Json -Compress

Write-Host "Deleting Schema $index"
$appdy.DeleteAnalyticsSchema($index)
Start-Sleep -Seconds 8
Write-Host "Creating Schema $index"
$appdy.CreateAnalyticsSchema($index,$schema)
Write-Host "Getting Apps "

## APPs totais
$apps = $appdy.GetApplicationsJSON() 

$apps2 = [System.Collections.ArrayList]::new()
$apps3 = [System.Collections.ArrayList]::new()

$count = 0

foreach ($app in $apps) {
    $count+=1
    if ($count -ge 3000) {
        $result = $apps3.Add($app)
    }
    else{

        $result = $apps2.Add($app)
    }
}

#### THREAD FOR PROCESS AND PARSE METRIC DURING THE COLLECTION

$thread_block = {
    $scriptBody = "Using module './Appdynamics.psm1'"

    $script = [ScriptBlock]::Create($scriptBody)

    . $script

    $source = "PublisherThread"

    $appdy.Log($source,"INFO","Publisher Thread Start")

    $report = $using:report
    $publisherON = $using:publisherON
    $publisherON = $true
    $auth = $using:auth
    $controller = $using:controller

    $index = $using:index
    $apiKey = $using:apiKey
    $accountName = $using:accountName

    try {

        $appdy = [Appdynamics]::new($controller,$auth)

        $appdy.SetAnalytics($apiKey,$accountName)

        $result = $appdy.GetLogin()

        $temp_report = $report

        #$appdy.debug = $TRUE

        if (-not $report.Count -eq 0 ) {

            $appdy.Log($source,"DEBUG","Publisher - Report > 0")

            $result = $appdy.PublishAnalyticsEvents($index,($temp_report | ConvertTo-Json))

            $appdy.Log($source,"INFO","Success Publishing "+$temp_report.count+" events")
            
        }

        $appdy.Log($source,"INFO","Publisher Thread Finished")
        

    }
    catch {
        $error_message = $_.Exception.Message
        $error_source = $_.Exception.Source 
        $source = "PublishAnalyticsEvents - Client"
        $appdy.Log($source,"ERROR","Publishing Events - Client")
        $appdy.Log($source,"ERROR",($_.Exception.InnerException.Message+" --- "+$_.Exception.InnerException.Data+" --- "+$_.Exception.InnerException.Source ))
        $appdy.Log($source,"ERROR","$error_source  - $error_message ")
    }
    finally {
        $publisherON = $false
    }


    
    
}

Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")"Collecting Node Info Details from Apps: "$apps.count

$count = 0
$perc_status_last = 0

foreach ($app in $apps2) {
    #Write-Progress -Id 1 -Activity "Total Apps to collect: $($apps.count)" -PercentComplete (($count/$apps.count)*100) -Status 'Starting Jobs'
    $count+=1


    $nodes = $appdy.GetReportingNodes($app.id,$start_time,$end_time)
    $error_count = 0
    if ($nodes[0] -eq "ERROR") {
        
        while ($error_count -lt 3) {
            $nodes = $appdy.GetReportingNodes($app.id,$start_time,$end_time)
            if ($nodes[0] -eq "ERROR") {
                $error_count += 1
            }
            else {
                $error_count = 10
            }
        }
    }

    if ($error_count -eq 3) {
        $source = "GetReportingNodes - Client"
        $appdy.Log($source,"ERROR","Error after 3 times - look to the wrapper errors for more details")
        $nodes = @()
    }
    elseif ($nodes[0] -eq "ERROR") {
        $source = "GetReportingNodes - Client"
        $appdy.Log($source,"ERROR","Unknown Error - look to the wrapper errors for more details")
        $nodes = @()
    }
    
    if ($nodes.count -eq 0 ) {
        "No nodes reporting in the last 60 minutes for "+$app.name | Out-File -FilePath "NoNodesApps.txt" -Append
    }else{
    
        $perc_status = [math]::Round(($count/$apps2.count)*100)

        if ($perc_status -ne $perc_status_last) {
            $appdy.Log("DrLicenseStatus","INFO","Completed: $perc_status%")
            Write-Host ("DrLicenseStatus - Completed: $perc_status%")
        }
        
        $perc_status_last = $perc_status

        $nodecount = 0
        $nodeGroups = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
        $nodeGroup = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))

        foreach ($node in $nodes) {
            
            $nodecount+=1

            if ($nodecount % 99 -eq 0) {
                $null = $nodeGroups.Add($nodeGroup)
                #$nodeGroup.Clear()
                $nodeGroup = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
                
            }
            else{
        
                $null = $nodeGroup.Add($node)
            }         
        }
        
        if ($nodeGroup.Count -gt 0) {
            $null = $nodeGroups.Add($nodeGroup)
            $nodeGroup = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
            $nodeGroup = @()
        }

        #### NODE THREAD 
        $script_block = {
            $scriptBody = "Using module './Appdynamics.psm1'"
            $script = [ScriptBlock]::Create($scriptBody)
            . $script
        
            $app = $using:app
            $report = $using:report
            $auth = $using:auth
            $controller = $using:controller
            $group = $using:group
            $start_time = $using:start_time
            $end_time = $using:end_time
            
        
            $appdy = [Appdynamics]::new($controller,$auth)

            $nodes = $group
        
        
        
            $result = $appdy.GetLogin()
        
            $nodes_id = ($nodes | Where-Object {$_.componentName -ne "Machine Agent" } | Select-Object -ExpandProperty nodeId) | ConvertTo-Json -Compress -AsArray
        
            $nodes_count = $nodes_id.count

            $appdy.Log("DrLicense","INFO","App: "+$app.name+" - Nodes: "+$nodes.count+" - Reporting Nodes and Not MachineAgent (Tier) nodes: $nodes_count")
        
            $appdy.Log("DrLicense","DEBUG"," IDS: $nodes_id" )
            $appdy.Log("DrLicense","DEBUG", "IDS count: "+$nodes_id.count )
        
            #$appdy.debug = $true
        
            if ($nodes_count -gt 0) {
                
                $appdy.Log("DrLicense","DEBUG","App: Getting Reporting Nodes Info")
            
                $nodes_info = $appdy.GetReportingNodesInfo($nodes_id, $start_time, $end_time ) 
            
                #$appdy.Log("DrLicense","INFO",($nodes_info | ConvertTo-Json))
            
                [System.Collections.ArrayList]$nodes_machine_info = $appdy.GetReportingNodesMachineInfo($nodes_id, $start_time, $end_time ) | Select-Object -Property hostName, machineId, agentId, nodeName
            
                
                [System.Collections.ArrayList]$nodes_info_appdy = $nodes_info | Select-Object -Property componentId, componentName, componentTypeName, productType, nodeId, nodeName, appServerAgentInstalled, machineAgentInstalled, appAgentVersion, jvmVersion, appServerRestartDate, healthMetricStats
            
        
                $counter=0
            
                $appdy.Log("DrLicense","DEBUG","Getting Reporting Nodes Info from "+$app.name)
            
                while ($nodes_info_appdy.count -gt ($counter -1) -AND $null -ne $nodes_info_appdy[$counter]) {

                    $app_perc_status = 0.0
                    $machine_perc_status = 0.0
                    $appServerAgentInstalled = "false"
                    $machineAgentInstalled = "false"
            
                    $status = ($nodes_info_appdy[$counter] | Select-Object -ExpandProperty healthMetricStats).state
            
                    $node_machine_info = $nodes_machine_info | Where-Object { $_.nodeName -eq $nodes_info_appdy[$counter].nodeName }
            
                    if ($nodes_info_appdy[$counter].appServerAgentInstalled -eq $TRUE) {
                        $app_perc_status = (($nodes_info_appdy[$counter] | Select-Object -ExpandProperty healthMetricStats) | Select-Object -ExpandProperty appServerAgentAvailability).percentage
                    }
                    if ($Member.machineAgentInstalled -eq $TRUE) {
                        $machine_perc_status = (($nodes_info_appdy[$counter] | Select-Object -ExpandProperty healthMetricStats) | Select-Object -ExpandProperty machineAgentAvailability).percentage
                    }
                    if ($nodes_info_appdy[$counter].appServerAgentInstalled) {
                        $appServerAgentInstalled = "true"
                    }
                    else {
                        $appServerAgentInstalled = "false"
                    }
                    if ($nodes_info_appdy[$counter].machineAgentInstalled) {
                        $machineAgentInstalled = "true"
                    }
                    else {
                        $machineAgentInstalled = "false"
                    }
            
                    $new_node = [PSCustomObject]::new
                    
                    $new_node = [PSCustomObject] @{
                        componentId = $nodes_info_appdy[$counter].componentId
                        componentName = $nodes_info_appdy[$counter].componentName
                        componentTypeName = $nodes_info_appdy[$counter].componentTypeName
                        productType = $nodes_info_appdy[$counter].productType
                        nodeId = $nodes_info_appdy[$counter].nodeId
                        nodeName = $nodes_info_appdy[$counter].nodeName
                        appAgentVersion = $nodes_info_appdy[$counter].appAgentVersion 
                        jvmVersion = $nodes_info_appdy[$counter].jvmVersion
                        appServerRestartDate = $nodes_info_appdy[$counter].appServerRestartDate
                        ApplicationName = $app.name
                        ApplicationId = $app.id
                    }
            
                    $new_node | Add-Member -MemberType NoteProperty -Name Status -Value $status
                    $new_node | Add-Member -MemberType NoteProperty -Name App_Status -Value $app_perc_status
                    $new_node | Add-Member -MemberType NoteProperty -Name Machine_Status -Value $machine_perc_status
                    $new_node | Add-Member -MemberType NoteProperty -Name AppServer_Agent_Installed -Value $appServerAgentInstalled
                    $new_node | Add-Member -MemberType NoteProperty -Name Machine_Agent_Installed -Value $machineAgentInstalled
            
                    $new_node | Add-Member -MemberType NoteProperty -Name HostName -Value $node_machine_info.hostName
                    $new_node | Add-Member -MemberType NoteProperty -Name MachineId -Value $node_machine_info.machineId
                    $new_node | Add-Member -MemberType NoteProperty -Name agentId -Value $node_machine_info.agentId
                    
                    $counter += 1
            
                    $report.Add($new_node)
                }
            }
            else{
                $appdy.Log("DrLicense","DEBUG","App: $($app.name) NOT Getting Reporting Nodes Info")
            }
        
        }
        ##### END NODE THREAD

        foreach ($group in $nodeGroups) {
            # Start MultiThread Jobs
            $job = Start-ThreadJob -ThrottleLimit 100 -ScriptBlock $script_block #-ArgumentList $group #$appdy #$_.name, $appdy.baseurl, $appdy.headers, $metric, $metricTime
            $jobs += $job
        }
        
        
    }
    if (($count % 50) -eq 0 ) {
        $appdy.Log("Publisher","INFO","Waiting jobs to start Publisher Thread")
        $jobs | Wait-Job | Out-Null

        $appdy.Log("Publisher","INFO","Starting Publisher Thread")
        $job = Start-ThreadJob -ThrottleLimit 100 -ScriptBlock $thread_block -name PublisherThread 
        Wait-Job -Id $job.Id | Out-Null
        Get-Job | Remove-Job -Force | Out-Null
        $report.Clear()
        $report = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
        $jobs = @()
        $appdy.Log("DrLicense","INFO","Cleaning Memory - Memory used before collection: $([System.GC]::GetTotalMemory($false))")
        [System.GC]::Collect()         
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        $appdy.Log("DrLicense","INFO","Memory Cleaned - Memory used after full collection: $([System.GC]::GetTotalMemory($true))")

    }
    
    
}
$count = 0
while ($(Get-job -State Running).count -gt 2 -OR $(Get-Job -State NotStarted).count -gt 0 ){#-AND $count -lt 5 ) {
    Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Node Metrics Collected: "$report.Count
    Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs: "(Get-Job).count
    Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs Not Started: "(Get-Job -State NotStarted).count
    Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs Running: "(Get-Job -State Running).count
    Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs Completed: "(Get-Job -State Completed).count
    Write-Host " - Jobs Failed: "(Get-Job -State Failed ).count


    Start-Sleep -Seconds 10
    $count += 1
}


Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs: "(Get-Job).count
Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs Not Started: "(Get-Job -State NotStarted).count
Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs Running: "(Get-Job -State Running).count
Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs Completed: "(Get-Job -State Completed).count
Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs Stopped: "(Get-Job -State Stopped ).count
Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs Failed: "(Get-Job -State Failed ).count
Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs Suspended: "(Get-Job -State Suspended ).count
Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Jobs Blocked: "(Get-Job -State Blocked ).count

Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " - Waiting All jobs to complete: "(Get-Job -State Running).count
$null = $jobs | Wait-Job 

Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - Nodes Collected: "$report.Count
Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " - Parsing Metrics"


$job = Start-ThreadJob -ThrottleLimit 10 -ScriptBlock $thread_block

Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " - Finishing Generating Report"

$null = $job | Wait-Job 

Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss")" - FIM -- "+(($start_drlicense_time - (Get-Date)) )