# How to Use the Region Selection Toolkit

_This page is a practical guide for running the Region Selection Toolkit, helping you evaluate and choose the optimal Azure region for your workloads._

Before proceeding with this Step by Step Guide, make sure you’ve completed the prerequisites and initial setup in [Getting Started](Setup-and-Prerequisites.md)

## Running the Toolkit Step-by-Step
Once your environment is ready and you have determined the input method, follow these steps to run the Region Selection Toolkit. It’s important to run the stages in order, as each stage uses data from the previous one. The steps below assume you’re using PowerShell:

### Authenticate and Set Context
Open a PowerShell prompt in the toolkit’s directory. If you’re in Azure Cloud Shell, you can navigate to the folder where you cloned the toolkit.
- **Log in to Azure:** Run `Connect-AzAccount` to authenticate to Azure.
- **Select the target subscription/s:** If you have multiple subscriptions, ensure the correct one is active. Use `Select-AzSubscription` `-SubscriptionId <YourSubscriptionID>` to switch the context to the subscription that contains the resources you want to analyse. This ensures all subsequent operations run against the intended subscription.

## 1. Run 1-Collect (Inventory Collection)
Next, gather the inventory of resources that will be evaluated. Run the script `Get-AzureServices.ps1` to collect the Azure resource inventory and properties, for yor relevant scope (resource group, subscription or multiple subscriptions). The script will generate a  `resources.json` and a `summary.json` file in the same directory. The `resources.json` file contains the full inventory of resources and their properties, while the `summary.json` file contains a summary of the resources collected. 

**If using Azure Resource Graph:** Run the `Get-AzureServices.ps1` script with your target scope. For example:

- To include Cost Information add parameter `-includeCost $true`. If you include this parameter, it will also generate a CSV file in the same directory. This CSV file can be used later in `3-CostInformation`. Note: This might take some time depending on how long it takes to download the cost information.

```powershell
Get-AzureServices.ps1 -includeCost $true
```

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
> Before proceeding, make sure that the output files are successful generated in the `1-Collect` folder with the name `resources.json`, `summary.json` and a `CSV file` if cost was included.

## 2. Run 2-AvailabilityCheck (Service Availability)
After collecting inventory, continue with `Get-AvailabilityInformation.ps1`. This script evaluates the availability of Azure services, resources, and SKUs across all regions. When combined with the output from the 1-Collect script, it provides a comprehensive overview of potential migration destinations, identifying feasible regions and the reasons for their suitability or limitations, such as availability constraints per region.

Note that this functionality is not yet complete and is a work in progress. Currently, this script associates every resource with its regional availability. Additionally, it maps the following SKUs to the regions where they are supported:
- microsoft.compute/disks
- microsoft.compute/virtualmachines
- microsoft.sql/managedinstances
- microsoft.sql/servers/databases
- microsoft.storage/storageaccounts

The `Get-AvailabilityInformation.ps1` script only needs to be run once to collect the availability information for all regions, which takes a little while. Run the following script: 

```powershell
Get-AvailabilityInformation.ps1
```
It will generate a number of json files in the same directory the important one is the `Availability_Mapping.json`

To check the availability of the resources in scope in a specific region run following script:

```powershell
Get-Region.ps1 -Region <Target-region>
```
This will generate `Availability_Mapping_<Region>.json` in the same directory. 

Example:
```powershell
Get-AvailabilityInformation.ps1
# Wait for the script to complete, this may take a while.
Get-Region.ps1 -region <target-region1>
# Example1: Get-Region.ps1 -region "east us"
# Example2: Get-Region.ps1 -region "west us"
# Example3: Get-Region.ps1 -region "sweden central"
```

## 3. Run 3-CostInformation (Cost Analysis)

The Azure public pricing API is used, meaning that, prices are **not** customer-specific, but are only used to calculate the relative cost difference between regions for each meter ID.

Navigate to the `3-CostInformation` folder and run the script using the `Perform-RegionComparison.ps1` script to do cost comparison with target Region(s). 

For example:
``` text
$regions = @("eastus", "brazilsouth", "australiaeast")
.\Perform-RegionComparison.ps1 -regions $regions -outputFormat json -reso
```

This will generate `region_comparison_RegionComparison.json` file

## 4. 7-Report

This script generates formatted Excel (`.xlsx`)reports based on the output from the previous check script. 

Navigate to the `7-Report` folder and run the `Get-Report.ps1`, also specify the path to the availability information and the cost comparision path. For example:

```powershell
.\Get-Report.ps1 -availabilityInfoPath ..\2-AvailabilityCheck\Availability_Mapping_<Region>.json -costComparisonPath ..\3-CostInformation\region_comparison_RegionComparison.json
```
The script generates an `.xlsx` file in the `7-report` folder, named `Availability_Report_CURRENTTIMESTAMP`.

Open the generated Excel file. The reports provide detailed information for each service, including:

### Service Availability Report

- **Resource type**
- **Resource count**
- **Implemented (origin) regions**
- **Implemented SKUs**
- **Availability in the Selected (target) regions**

## Cost Comparison Report

- **Meter ID**
- **Service Name**
- **Meter Name**
- **Product Name**
- **SKU Name**
- **Retail Price per region**
- **Price Difference to origin region per region**

These reports help you analyze service compatibility and cost differences across different regions.







































