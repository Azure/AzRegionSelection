# 1-Collect (Inventory Collection)
Gathers the inventory of resources that will be evaluated. Run the script `Get-AzureServices.ps1` to collect the Azure resource inventory and properties, for yor relevant scope (resource group, subscription or multiple subscriptions). The script will generate a  `resources.json` and a `summary.json` file in the same directory. The `resources.json` file contains the full inventory of resources and their properties, while the `summary.json` file contains a summary of the resources collected. 

## Examples 
### If using Azure Resource Graph:
Run the `Get-AzureServices.ps1` script with your target scope. For example:

- To include Cost Information add parameter `-includeCost $true`. If you include this parameter, it will also generate a CSV file in the same directory. This CSV file can be used later in `3-CostInformation`. Note: This might take some time depending on how long it takes to download the cost information.

```powershell
Get-AzureServices.ps1 -includeCost $true
```

- To collect the inventory for a single resource group, run the script as follows:

```powershell
Get-AzureServices.ps1 -scopeType resourceGroup -resourceGroupName <resource-group-name> -subscriptionId <subscription-id>
```

- To collect the inventory for a single subscription, cost not included, run the script as follows:

```powershell
Get-AzureServices.ps1 -scopeType subscription -subscriptionId <subscription-id>
```

- To collect the inventory for multiple subscriptions, you will need to create a json file containing the subscription ids in scope. See [here](./subscriptions.json) for a sample json file. Once the file is created, run the script as follows:

```powershell
Get-AzureServices.ps1 -multiSubscription -workloadFile <path-to-workload-file>
```

### If using an Azure Migrate export:
Run `Get-RessourcesFromAM.ps1` against an Azure Migrate `Assessment.xlsx` file to convert the VM & Disk SKUs into the same output as `Get-AzureServices.ps1` For example:

```powershell
Get-RessourcesFromAM.ps1 -filePath "C:\path\to\Assessment.xlsx" -outputFile "C:\path\to\summary.json"
```
