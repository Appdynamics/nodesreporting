# Nodes Reporting

Saas and On prem Nodes reporting Counter Tool - Application/Server Level

The Nodes Reporting Tool was created because of the lack of Application/Server nodes reporting visibility in our UI, so this tool give visibility mainly to our SaaS customers about the nodes reporting by customer Application, Environment (eg. Dev vs Prod), Agents with old versions, App w/ machine agents, etc. This give the opportunity to our customers understand their applications growth and nodes usage for future expansions.

This Tool now is only running mannually in next releases I will include the appdy "monitor.xml", remove all console logs and add create some custom metrics.

Dr License use the Appdynamics Powershell Wrapper to talk to Appdynamics APIs

[Appdynamics Powershell Core Wrapper](https://github.com/diegopereiraeng/appdynamics-powershell-core-wrapper)

This Tool will produce these data for each node in all your apps that are reporting in the last 5 minutes:
```
ApplicationName
ApplicationId
nodeId
nodeName
MachineId
agentId
componentId
componentName
appServerRestartDate
jvmVersion
componentTypeName
productType
App_Status
Machine_Status
AppServer_Agent_Installed
Machine_Agent_Installed
HostName
appAgentVersion
Status
```

# Configuration

Please open the script DrLicense.ps1 and edit the below parameters:

![Main Parameter](https://github.com/Appdynamics/nodesreporting/blob/master/DrLicense_Parameters.png)

```
Controller Address
Authentication
Analytics API Key
Controller Global Account Name
Analytics Schema
```



# Dashboard

I will include in the extension in the next releases.

![Sample Dashboard](https://github.com/Appdynamics/nodesreporting/blob/master/Dashboard-DrLicense.jpg)

# Important

This tool is not supported by Appdynamics Support

