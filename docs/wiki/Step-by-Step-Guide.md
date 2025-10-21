# How to Use the Region Selection Toolkit

_This page is a practical guide for running the Region Selection Toolkit, helping you evaluate and choose the optimal Azure region for your workloads._

Before proceeding with this Step by Step Guide, make sure you’ve completed the prerequisites and initial setup in [Getting Started](Setup-and-Prerequisites.md)

## Running the Toolkit Step-by-Step
Once your environment is ready and you have determined the input method, follow these steps to run the Region Selection Toolkit. It’s important to run the stages in order, as each stage uses data from the previous one. The steps below assume you’re using PowerShell:

### Authenticate and Set Context
Open a PowerShell prompt in the toolkit’s directory. If you’re in Azure Cloud Shell, you can navigate to the folder where you cloned the toolkit.
- **Log in to Azure:** Run `Connect-AzAccount` to authenticate to Azure.

## Run 1-Collect (Inventory Collection)

Run the script `Get-AzureServices.ps1` to collect the Azure resource inventory and properties, for yor relevant scope (resource group, subscription or multiple subscriptions). The script will generate a  `resources.json` and a `summary.json` file in the same directory. The `resources.json` file contains the full inventory of resources and their properties, while the `summary.json` file contains a summary of the resources collected. For examples on how to run the script for different scopes please see [1-Collect Examples](1-Collect.md).

**If using Azure Resource Graph:** 

```powershell
Get-AzureServices.ps1 -includeCost $true
```

**If using an Azure Migrate export:** Run `Get-RessourcesFromAM.ps1` against an Azure Migrate `Assessment.xlsx` file to convert the VM & Disk SKUs into the same output as `Get-AzureServices.ps1` For example:

```powershell
Get-RessourcesFromAM.ps1 -filePath "C:\path\to\Assessment.xlsx" -outputFile "C:\path\to\summary.json"
```
> [!NOTE]
> Before proceeding, make sure that the output files (`resources.json`, `summary.json` and a `CSV file`) are generated in the `1-Collect` folder.

## Run 2-AvailabilityCheck (Service Availability)

This script will check the availability of the services in the target region based on the inventory collected in the previous step. Note that this functionality is not yet complete and is a work in progress. For examples on how to run the script please see [2-AvailabilityCheck Examples](2-AvailabilityCheck.md)

After collecting inventory, continue with `Get-AvailabilityInformation.ps1`. It will generate a number of json files in the same directory the important one is the `Availability_Mapping.json` Run the following script: 

```powershell
Get-AvailabilityInformation.ps1
```

Check the availability of the resources in scope for a specific region. This will generate a file named `Availability_Mapping_<Region>.json` in the same directory. Run the following script:

```powershell
Get-Region.ps1 -Region <Target-region>
```

## Run 3-CostInformation (Cost Analysis)

The Azure public pricing API is used, meaning that, prices are **not** customer-specific, but are only used to calculate the relative cost difference between regions for each meter ID.

Navigate to the `3-CostInformation` folder and run the script using the `Perform-RegionComparison.ps1` script to do cost comparison with target Region(s). 

For example:
```powershell
$regions = @("eastus", "brazilsouth", "australiaeast")
.\Perform-RegionComparison.ps1 -regions $regions -outputFormat json -reso
```

This will generate `region_comparison_RegionComparison.json` file

## Run 7-Report

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







































