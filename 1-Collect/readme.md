## Assessment script

This script is intended to assess Azure services currently implemented in a given scope. The script will produce a report containing information about all services in scope as well as summary report detailing the number of individual services, as well as SKUs in use if relevant.

To use the script do the following from a powershell command line:
1. Log on to Azure using `Connect-AzAccount` and select the appropriate subscription using `Select-AzSubscription`.
2. Navigate to the 1-Collect folder and run the script using `.\Get-AzureServices.ps1`. The script will generate a report in the `1-Collect` folder with the name `resources.json` as well as `summary.json`.