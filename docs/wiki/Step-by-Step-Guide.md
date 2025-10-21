# How to Use the Region Selection Toolkit

_This page is a practical guide for running the Region Selection Toolkit, helping you evaluate and choose the optimal Azure region for your workloads._

Before proceeding with this Step by Step Guide, make sure you’ve completed the prerequisites and initial setup in [Getting Started](Setup-and-Prerequisites.md)

## Running the Toolkit Step-by-Step
Once your environment is ready and you have determined the input method, follow these steps to run the Region Selection Toolkit. It’s important to run the stages in order, as each stage uses data from the previous one. The steps below assume you’re using PowerShell:

### Authenticate and Set Context
Open a PowerShell prompt in the toolkit’s directory. If you’re in Azure Cloud Shell, you can navigate to the folder where you cloned the toolkit.
- **Log in to Azure:** Run `Connect-AzAccount` to authenticate to Azure.
- **Select the target subscription/s:** If you have multiple subscriptions, ensure the correct one is active. Use `Select-AzSubscription` `-SubscriptionId <YourSubscriptionID>` to switch the context to the subscription that contains the resources you want to analyse. This ensures all subsequent operations run against the intended subscription.

### 1. Run 1-Collect (Inventory Collection)
Next, gather the inventory of resources that will be evaluated. Run the script `Get-AzureServices.ps1` to collect the Azure resource inventory and properties, for yor relevant scope (resource group, subscription or multiple subscriptions). The script will generate a  `resources.json` and a `summary.json` file in the same directory. The `resources.json` file contains the full inventory of resources and their properties, while the `summary.json` file contains a summary of the resources collected. 

**If using Azure Resource Graph:** Run the `Get-AzureServices.ps1` script with your target scope. For example:

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

**If using an Azure Migrate export:** Run `Get-RessourcesFromAM.ps1` against an Azure Migrate `Assessment.xlsx` file to convert the VM & Disk SKUs into the same output as `Get-AzureServices.ps1` For example:

```powershell
Get-RessourcesFromAM.ps1 -filePath "C:\path\to\Assessment.xlsx" -outputFile "C:\path\to\summary.json"
```
> [!NOTE]
> Before proceeding, make sure that the output files are successful generated in the `1-Collect` folder with the name `resources.json` as well as `summary.json`.

### 2. Run 2-AvailabilityCheck (Service Availability)
After collecting inventory, continue with `2-AvailabilityCheck/Get-AvailabilityInformation.ps1`. This script evaluates the availability of Azure services, resources, and SKUs across different regions. When combined with the output `resources.json`, it provides a comprehensive overview of potential migration destinations, identifying feasible regions based on Service Availability. Note that this functionality is not yet complete and is a work in progress.

It will generate a `services.json` file in the same directory, which contains the availability information for the services in the target region.

Currently, this script associates every resource with its regional availability. Additionally, it maps the following SKUs to the regions where they are supported:
- microsoft.compute/disks
- microsoft.compute/virtualmachines
- microsoft.sql/managedinstances
- microsoft.sql/servers/databases
- microsoft.storage/storageaccounts

1. Navigate to the `2-AvailabilityCheck` folder and run the script using `.\Get-AvailabilityInformation.ps1`. The script will generate report files in the `2-AvailabilityCheck` folder.

#### Per region filter script
To check the availability of services in a specific region, it is necessary to first run the `Get-AvailabilityInformation.ps1` script which will collect service availability in all regions. The resulting json files is then used with the `Get-Region.ps1` script to determine specific service availability for one or more regions to be used for reporting eventually. Note that the `Get-AvailabilityInformation.ps1` script only needs to be run once to collect the availability information for all regions, which takes a little while. 

After that, you can use the`Get-Region.ps1` script to check the availability of services in specific regions. Availability information is available in the `Availability_Mapping_<Region>.json` file, which is generated in the same directory as the script.

```powershell
Get-AvailabilityInformation.ps1
# Wait for the script to complete, this may take a while.
Get-Region.ps1 -region <target-region1>
# Example1: Get-Region.ps1 -region "east us"
# Example2: Get-Region.ps1 -region "west us"
# Example3: Get-Region.ps1 -region "sweden central"
```

### 3. Run 3-CostInformation (Cost Analysis)
This step contains two scripts. One that retrives cost information about resources inscope and second script uses public API to compare cost between the exsiting resource region and the one or more target regions. 

For this we use the Microsoft.CostManagement provider of each subscription. It will query the cost information for the resources collected in the previous step and compare cost diffrences of the regions in scope and generate a `cost.json` file in the same directory. Note that this is just standard pricing, which means customer discounts are **not** included.

The input file is `resources.json` produced by the `1-Collect` script.

1. Requires Az.CostManagement module version 0.4.2.
`PS1> Install-Module -Name Az.CostManagement`

2. Navigate to the `3-CostInformation` folder and run the script using `.\Get-CostInformation.ps1`. The script will generate a CSV file in the current folder.

#### Perform-RegionComparison.ps1

This script builds on the collection step by comparing pricing across Azure regions for the meter ID's retrieved earlier.
The Azure public pricing API is used, meaning that:
- No login is needed for this step
- Prices are *not* customer-specific, but are only used to calculate the relative cost difference between regions for each meter

As customer discounts tend to be linear (for example, ACD is a flat rate discount across all PAYG Azure spend), the relative price difference between regions can still be used to make an intelligent estimate of the cost impact of a workload move.

Instructions for use:

1. Prepare a list of target regions for comparison. This can be provided at the command line or stored in a variable before calling the script.
2. Ensure the `resources.json` file is present (from the running of the collector script).
2. Run the script using `.\Perform-RegionComparison.ps1`. The script will generate output files in the current folder.

For example:
``` text
$regions = @("eastus", "brazilsouth", "australiaeast")
.\Perform-RegionComparison.ps1 -regions $regions -outputType json
```








































