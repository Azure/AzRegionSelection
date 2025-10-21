# How to Use the Region Selection Toolkit
_This page is a practical guide for running the Region Selection Toolkit, helping you evaluate and choose the optimal Azure region for your workloads._

## Prerequisites
Before using the toolkit, ensure the following prerequisites are met:
- **Azure Subscription Access:** You should have access to the Azure subscription(s) containing the workload you want to analyse. At minimum, read permissions (e.g. **Azure Reader role**) on the relevant resources are required to gather inventory. If analysing a planned deployment (with no existing Azure resources yet), you can skip resource access but will need an Azure Migrate assessment export (see Input Data below).
- To run `3-CostInformation`, ensure that you have **Cost Management Reader access** to all subscriptions in scope.

- **Environment:** Prepare a PowerShell environment to run the toolkit. The toolkit is implemented in PowerShell scripts, so you can run it on Windows, Linux, or in the Azure Cloud Shell (which comes pre-configured with Azure PowerShell). Ensure you have **PowerShell 7.x (Core)** installed (PowerShell 7.5.1 or later is recommended).

- **Azure PowerShell Modules:** Install the necessary Azure PowerShell modules (if using Azure Cloud Shell, these are already available). The key modules needed include:

  - **Az.Accounts** (for logging in and selecting subscriptions) – version 4.1.0 or later

  - **Az.ResourceGraph** (for inventory queries) – version 1.2.0 or later

  - (Optional) **Az.Monitor** (for any performance metrics, if used) – version 5.2.2 or later

- **Azure Login:** You must be able to authenticate to Azure. If running locally, use Connect-AzAccount to sign in with your Azure credentials (or ensure your Azure CLI/PowerShell context is already logged in).

## Installation (Getting the Toolkit)
To obtain the Region Selection Toolkit on your machine or environment:
1. **Download or Clone** the toolkit’s repository (e.g., via Git): The toolkit is provided as a set of scripts in a GitHub repository (e.g. `Azure/AzRegionSelection`). You can clone it using `git clone https://github.com/Azure/AzRegionSelection.git`, or download the repository ZIP and extract it.
2. **Directory Structure:** After retrieval, you should have a directory containing the toolkit scripts. Key sub-folders include `1-Collect`, `2-AvailabilityCheck`, `3-CostInformation`, and `7-Report` (these correspond to different stages of the analysis). It’s important to keep this structure intact. You do **not** need to compile anything – the toolkit is ready to run via PowerShell scripts.

> [!NOTE]
> Ensure your environment (local machine or Cloud Shell) has network access to Azure endpoints. The toolkit may call Azure APIs (for resource data and pricing information), so an internet connection is required when running it.

## Input Data: Providing a Workload Inventory
The first step in using the toolkit is to provide an inventory of the workload’s Azure resources. The Region Selection Toolkit supports two main input methods for this inventory:

- **A.** **Automatic Inventory via Azure Resource Graph:** If the workload is already deployed in Azure (or you have an existing Azure environment you want to evaluate), the toolkit can automatically collect the resource list. In this case, you’ll run the `1-Collect` script which uses Azure Resource Graph to retrieve all resources in the specified subscription or resource group. This requires the prerequisites above (Azure login and appropriate permissions). You will specify which subscription (or other scope) to query.

- **B.** **Import from Azure Migrate Assessment:** If you are planning a migration (for example, moving on-premises or other cloud workloads to Azure) and have used Azure Migrate to assess your environment, you can use that data as input. First, export the Azure Migrate assessment results (Azure Migrate allows exporting discovered VM and resource metadata to files such as Excel/CSV). Then, the toolkit’s `1-Collect` stage can ingest this file to create an inventory of resources. Ensure the exported data is in a format the toolkit expects (check the toolkit documentation for the exact file format or template required). For instance, you might need to supply a parameter like `-InventoryFile <path>` when running the collection script, pointing to the Azure Migrate output.


## Running the Toolkit Step-by-Step
Once your environment is ready and you have determined the input method, follow these steps to run the Region Selection Toolkit. It’s important to run the stages in order, as each stage uses data from the previous one. The steps below assume you’re using PowerShell:

### Authenticate and Set Context
Open a PowerShell prompt in the toolkit’s directory. If you’re in Azure Cloud Shell, you can navigate to the folder where you cloned the toolkit.
- **Log in to Azure:** Run `Connect-AzAccount` if you haven’t already authenticated. This will open a browser prompt (or use device code flow in Cloud Shell) for Azure login. After logging in, your session is connected to Azure.
- **Select the target subscription:** If you have multiple subscriptions, ensure the correct one is active. Use `Select-AzSubscription` `-SubscriptionId <YourSubscriptionID>` to switch the context to the subscription that contains the resources you want to analyse. This ensures all subsequent operations run against the intended subscription. (If you have only one subscription or have already set the context, this step is done automatically by Connect-AzAccount.)

### 1. Run 1-Collect (Inventory Collection)
Next, gather the inventory of resources that will be evaluated. Run the script `Get-AzureServices.ps1` to collect the Azure resource inventory and properties, for yor relevant scope (resource group, subscription or multiple subscriptions). The script will generate a  `resources.json` and a `summary.json` file in the same directory. The `resources.json` file contains the full inventory of resources and their properties, while the `summary.json` file contains a summary of the resources collected. 

**If using Azure Resource Graph:** Run the collection script with your target scope. For example:

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

**If using an Azure Migrate export:** Ensure the Azure Migrate data file is accessible. Run `Get-RessourcesFromAM.ps1` against an Azure Migrate `Assessment.xlsx` file to convert the VM & Disk SKUs into the same output as `Get-AzureServices.ps1` For example:

```powershell
Get-RessourcesFromAM.ps1 -filePath "C:\path\to\Assessment.xlsx" -outputFile "C:\path\to\summary.json"
```
> [!NOTE]
> Before proceeding, get sure that the output files are successful generated in the `1-Collect` folder with the name `resources.json` as well as `summary.json`.

### 2. Run 2-AvailabilityCheck (Service Availability)
After collecting inventory, continue with `2-AvailabilityCheck/Get-AvailabilityInformation.ps1`. This script evaluates the availability of Azure services, resources, and SKUs across different regions. When combined with the output from the `1-Collect` script, it provides a comprehensive overview of potential migration destinations, identifying feasible regions and the reasons for their suitability or limitations, such as availability constraints per region.

It will generate a `services.json` file in the same directory, which contains the availability information for the services in the target region. Note that this functionality is not yet complete and is a work in progress.

Currently, this script associates every resource with its regional availability. Additionally, it maps the following SKUs to the regions where they are supported:
* microsoft.compute/disks
* microsoft.compute/virtualmachines
* microsoft.sql/managedinstances
* microsoft.sql/servers/databases
* microsoft.storage/storageaccounts

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
This script uses public API to compare cost between the exsiting resource region and the one or more target regions. For this we use the Microsoft.CostManagement provider of each subscription. It will query the cost information for the resources collected in the previous step and compare cost diffrences of the regions in scope and generate a `cost.json` file in the same directory. Note that this is just standard pricing, which means customer discounts are **not** included.

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








































