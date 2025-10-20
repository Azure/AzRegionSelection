# How to Use the Region Selection Toolkit
_This page is a practical guide for running the Region Selection Toolkit, helping you evaluate and choose the optimal Azure region for your workloads._

## Prerequisites
Before using the toolkit, ensure the following prerequisites are met:
- **Azure Subscription Access:** You should have access to the Azure subscription(s) containing the workload you want to analyse. At minimum, read permissions (e.g. **Azure Reader role**) on the relevant resources are required to gather inventory. If analysing a planned deployment (with no existing Azure resources yet), you can skip resource access but will need an Azure Migrate assessment export (see Input Data below).

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

### 1. Authenticate and Set Context
Open a PowerShell prompt in the toolkit’s directory. If you’re in Azure Cloud Shell, you can navigate to the folder where you cloned the toolkit.
- **Log in to Azure:** Run `Connect-AzAccount` if you haven’t already authenticated. This will open a browser prompt (or use device code flow in Cloud Shell) for Azure login. After logging in, your session is connected to Azure.
- **Select the target subscription:** If you have multiple subscriptions, ensure the correct one is active. Use `Select-AzSubscription` `-SubscriptionId <YourSubscriptionID>` to switch the context to the subscription that contains the resources you want to analyse. This ensures all subsequent operations run against the intended subscription. (If you have only one subscription or have already set the context, this step is done automatically by Connect-AzAccount.)

### 2. Run 1-Collect (Inventory Collection)
Next, gather the inventory of resources that will be evaluated:
- **If using Azure Resource Graph (existing Azure resources):** Run the collection script with your target scope. For example:
```powershell
# Run inventory collection for a subscription
PS> cd 1-Collect
PS> .\1-Collect.ps1 -SubscriptionId "<SUBSCRIPTION_ID>" -OutputFile "inventory.json"
```
Replace `<SUBSCRIPTION_ID>` with your Azure Subscription ID (or you might use `-SubscriptionName "Name"` if supported by the script). This will query Azure Resource Graph and collect details of resources in that subscription. The script will likely output the collected inventory to a file (e.g., `inventory.json` or a similar format) or to an in-memory object that subsequent scripts will use. If your scope is a resource group or management group, use the appropriate parameters (check script help by running `Get-Help .\1-Collect.ps1 -Full` for available options).

- **If using an Azure Migrate export:** Ensure the Azure Migrate data file is accessible (for example, copied into the toolkit directory or a known path). Run the collection script with a parameter to import that file. For example:
```powershell
PS> cd 1-Collect
PS> .\1-Collect.ps1 -ImportFile "MyMigrateExport.csv" -OutputFile "inventory.json"
```
The script will parse the Azure Migrate assessment data and produce the inventory in the format needed for the next steps.
The output of `1-Collect` is a consolidated list of your workload’s resources and their attributes, which will be used to evaluate region compatibility. Once this step completes, you should have an inventory object or file ready. The console may show a summary (e.g., “100 resources collected from subscription XYZ”). If there are errors (like permission issues or file parse issues), address them before proceeding.

### 2. Run 2-AvailabilityCheck (Service Availability and Compliance Analysis)
With the inventory in hand, run the second stage to analyse Azure regions against service availability and related factors:
```powershell
PS> cd ..\2-AvailabilityCheck
PS> .\2-AvailabilityCheck.ps1 -Inventory "inventory.json" -Regions "all"
```
This script takes the inventory (from the previous step) and checks which Azure regions can support those resources. It will likely compare each resource’s Azure service against a global services-by-region list. By default, the toolkit may evaluate **all public Azure regions** or a broad set of regions. You might have the option to limit the regions in consideration (for example, using a `-Regions` parameter as shown, where you could specify a list like `"westeurope,eastus2"` if you only want specific regions evaluated). If unspecified, it defaults to all relevant regions.

During this step, the toolkit will:
- Identify any regions where a required service is **not available**. Such regions would be marked as incompatible for your workload (or flagged for missing services).
- Check for compliance or sovereignty flags (for example, if your inventory includes resources subject to data residency rules, the script might note which regions are in the same geography or meet specific compliance requirements). It may use predefined mappings (e.g., marking government cloud regions, EU regions, etc.).

The output of this stage is typically an interim analysis which shows, for each region (or each resource vs region matrix), the availability result. This might be saved to an output file like `availability.json` or similar. The details might include lists of any **unsupported services per region** or compliance notes (e.g., “Region X is in Gov cloud, skipped unless specifically needed” as a note).

### 3. Run 3-CostInformation (Cost Analysis)
Next, run the cost comparison stage to evaluate cost differences across regions:
```powershell
PS> cd ..\3-CostInformation
PS> .\3-CostInformation.ps1 -Inventory "inventory.json" -RegionAnalysis "availability.json" -OutputFile "costs.json"
```


