# Getting Started

_This page is a guide for setup and prerequisites needed bafore running the Region Selection Toolkit._

## Prerequisites
Before using the toolkit, ensure the following prerequisites are met:
- **Azure Subscription Access:**
  - You should have access to the Azure subscription(s) containing the workload you want to analyse. At minimum, read permissions (e.g. **Azure Reader role**) on the relevant resources are required to gather inventory. If analysing a planned deployment (with no existing Azure resources yet), you can skip resource access but will need an Azure Migrate assessment export (see Input Data below).
  - To run `3-CostInformation`, ensure that you have **Cost Management Reader access** to all subscriptions in scope.

- **Environment:** Prepare a PowerShell environment to run the toolkit. The toolkit is implemented in PowerShell scripts, so you can run it on Windows, Linux, or in the Azure Cloud Shell. Ensure you have **PowerShell Core 7.5.1** or later installed.

- **Azure PowerShell Modules:** Install the necessary Azure PowerShell modules (if using Azure Cloud Shell, these are already available).

  - Azure Powershell module `Az.ResourceGraph 1.2.0` or later
  - Azure Powershell module `Az.Accounts 4.1.0` or later
    
  If using Azure migrate as input file:
  - Azure Powershell module `Az.Monitor 5.2.2` or later
  - Azure Powershell `ImportExcel` module for Azure Migrate script

- **Azure Login:** You must be able to authenticate to Azure. If running locally, use `Connect-AzAccount` to sign in with your Azure credentials.

## Installation (Getting the Toolkit)
To obtain the Region Selection Toolkit on your machine or environment:
1. **Download or Clone** the toolkit’s repository (e.g., via Git): The toolkit is provided as a set of scripts in a GitHub repository (e.g. `Azure/AzRegionSelection`). You can clone it using `git clone https://github.com/Azure/AzRegionSelection.git`, or download the repository ZIP and extract it.

2. **Directory Structure:** After retrieval, you should have a directory containing the toolkit scripts. Key sub-folders include `1-Collect`, `2-AvailabilityCheck`, `3-CostInformation`, and `7-Report` (these correspond to different stages of the analysis). It’s important to keep this structure intact. You do **not** need to compile anything – the toolkit is ready to run via PowerShell scripts.

## Input Data: Providing a Workload Inventory
The first step in using the toolkit is to provide an inventory of the workload’s Azure resources. The Region Selection Toolkit supports two main input methods for this inventory:

**A.** **Automatic Inventory via Azure Resource Graph:** If the workload is already deployed in Azure, the toolkit can automatically collect the resource list. In this case, you’ll run the `1-Collect` script which uses Azure Resource Graph to retrieve all resources in the specified subscription or resource group. This requires the prerequisites above (Azure login and appropriate permissions). You will specify which subscription (or other scope) to query.

**B.** **Import from Azure Migrate Assessment:** If you are planning a migration (for example, moving on-premises or other cloud workloads to Azure) and have used Azure Migrate to assess your environment, you can use that data as input. First, export the Azure Migrate assessment results (Azure Migrate allows exporting discovered VM and resource metadata to files such as Excel/CSV). Then, the toolkit’s `1-Collect` stage can ingest this file to create an inventory of resources. Ensure the exported data is in a format the toolkit expects (check the toolkit documentation for the exact file format or template required).

## Next Up: [How to use Region Selection Toolkit](Step-by-Step-Guide.md)
