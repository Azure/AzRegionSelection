# Background

This guide describes how to leverage the Region selection toolkit toolkit when checking can your current Azure workload be deployed in another region.  

> Note that this is a preview solution intended to encourage feedback for further development which should be tested in a safe environment before using in production to protect against possible failures/unnecessary cost.
> Also note that this repo is public and as such you should never upload or otherwise divulge sensitive information to this repo. If there is any concern, please contact your Microsoft counterparts for detailed advice.

The repo at present contains code and details for the following:

- Script and supporting files to collect Azure resource inventory and properties from either an Azure resource group, an Azure subscription (default behavior) or multiple Azure subscriptions. This functionality is contained in the 1-Collect directory.
- Script to convert the output Excel file from a Azure Migrate Assessment to the same format.
- Script to determine service availability in the target region based on the inventory collected in the previous step. This functionality is contained in the 2-AvailabilityCheck directory. Note that this functionality is not yet complete and is a work in progress.

## Prerequisites

1. Microsoft Entra ID Tenant.
1. Azure RBAC Reader access to minimum one resource group for when collecting inventory. Note that depending on the scope of the inventory collection, you may need to have Reader access to either a single resource group, a subscription or multiple subscriptions.
1. You will need to have the following installed on the platform you are running the scripts from:
    - PowerShell Core 7.5.1 or later
    - Azure Powershell module Az.Monitor 5.2.2 or later
    - Azure Powershell module Az.ResourceGraph 1.2.0 or later
    - Azure Powershell module Az.Accounts 4.1.0 or later
    - Azure Powershell ImportExcel module for Azure Migrate script

## High Level Steps

- Fork this repo to your own GitHub organization, you should not create a direct clone of the repo. Pull requests based off direct clones of the repo will not be allowed.
- Clone the repo from your own GitHub organization to whatever platform you are using to access Azure.
- Open the PowerShell console and navigate to the directory where you cloned the repo.
- Navigate to the `1-Collect` directory.
- Logon to Azure with an account that has the required permissions to collect the inventory using `Connect-AzAccount`.
- Run the script `Get-AzureServices.ps1` to collect the Azure resource inventory and properties, for yor relevant scope (resource group, subscription or multiple subscriptions). The script will generate a resources.json and a summary.json file in the same directory. The resources.json file contains the full inventory of resources and their properties, while the summary.json file contains a summary of the resources collected. For examples on how to run the script for different scopes please see 1-Collect scope examples - [1-Collect Scope Examples](#1-collect-scope-examples) below.
- Alternatively you can run `Get-RessourcesFromAM.ps1` against an Azure Migrate `Assessment.xlsx` file to convert the VM & Disk SKUs into the same output as `Get-AzureServices.ps1` to be used further with the `2-AvailabilityCheck/Get-AvailabilityInformation.ps1` script.
- After collecting the inventory, the intent is that you can use the `2-AvailabilityCheck/Get-AvailabilityInformation.ps1` script to check the availability of the services in the target region. This script will generate a services.json file in the same directory, which contains the availability information for the services in the target region. Note that this functionality is not yet complete and is a work in progress.

## 1-Collect Scope Examples

- To collect the inventory for a single resource group, run the script as follows:

```powershell
Get-AzureServices.ps1 -scopeType resourceGroup -resourceGroupName <resource-group-name> -subscriptionId <subscription-id>
```

- To collect the inventory for a single subscription, run the script as follows:

```powershell
Get-AzureServices.ps1 -scopeType subscription -subscriptionId <subscription-id>
```

- To collect the inventory for multiple subscriptions, you will need to create a json file containing the subscription ids in scope. See [here](./subscriptions.json) for a sample json file. Once the file is created, run the script as follows:

```powershell
Get-AzureServices.ps1 -multiSubscription -workloadFile <path-to-workload-file>
```

### 1.1-Azure Migrate Script Examples

```powershell
Get-RessourcesFromAM.ps1 -filePath "C:\path\to\Assessment.xlsx" -outputFile "C:\path\to\summary.json"
```
