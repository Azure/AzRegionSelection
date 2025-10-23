# 2-AvailabilityCheck

## Availability check script
This script evaluates the availability of Azure services, resources, and SKUs across all regions. When combined with the output from the 1-Collect script, it provides a comprehensive overview of potential migration destinations, identifying feasible regions and the reasons for their suitability or limitations, such as availability constraints per region.

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

## Filter by Region script

To check the availability of the resources in scope in a specific region run following script:

```powershell
Get-Region.ps1 -Region <Target-region>
```
This will generate `Availability_Mapping_<Region>.json` in the same directory. 

## Example:
```powershell
Get-AvailabilityInformation.ps1
# Wait for the script to complete, this may take a while.
Get-Region.ps1 -region <target-region1>
# Example1: Get-Region.ps1 -region "east us"
# Example2: Get-Region.ps1 -region "west us"
# Example3: Get-Region.ps1 -region "sweden central"
```
