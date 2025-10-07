# Current implementation to Azure availabilities mapping scripts

## Availability check script

This script evaluates the availability of Azure services, resources, and SKUs across different regions. When combined with the output from the 1-Collect script, it provides a comprehensive overview of potential migration destinations, identifying feasible regions and the reasons for their suitability or limitations, such as availability constraints per region.

Currently, this script associates every resource with its regional availability. Additionally, it maps the following SKUs to the regions where they are supported:
* microsoft.compute/disks
* microsoft.compute/virtualmachines
* microsoft.sql/managedinstances
* microsoft.sql/servers/databases
* microsoft.storage/storageaccounts

To use the script do the following from a powershell command line:
1. Log on to Azure using `Connect-AzAccount` and select the appropriate subscription using `Select-AzSubscription`.
2. Run `.\Get-AzureServices.ps1` from `1-Collect` folder.
3. Get sure that the output files are successful generated in the `1-Collect` folder with the name `resources.json` as well as `summary.json`.
4. Navigate to the `2-AvailabilityCheck` folder and run the script using `.\Get-AvailabilityInformation.ps1`. The script will generate report files in the `2-AvailabilityCheck` folder.

## Per region filter script

This script processes the output from the previous script to extract data for a single, specified region.

To use the script do the following from a powershell command line:
1. Execute the `.\Get-AvailabilityInformation.ps1` script first, as previously outlined.
2. Run `.\Get-Region.ps1` from `2-AvailabilityCheck` folder. The script will generate report files in the `2-AvailabilityCheck` folder.