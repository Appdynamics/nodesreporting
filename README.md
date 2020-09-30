# Dr license

Saas and On prem License counter tool - Application/Node Level

Dr License was created by the necessity of getting Application/Node license level controll for the customers.

This Tool now is only running mannually in next releases I will include the appdy "monitor.xml", remove all console logs and add create some custom metrics.

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

![Main Parameter](https://github.com/Appdynamics/drlicense/blob/master/DrLicense_Parameters.png)

```
Controller Address
Authentication
Analytics API Key
Controller Global Account Name
Analytics Schema
```



# Dashboard

I will include in the extension in the next releases.

![Sample Dashboard](https://github.com/Appdynamics/drlicense/blob/master/Dashboard-DrLicense.jpg)

# Important

This tool is not supported by Appdynamics Support

