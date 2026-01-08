# 7-Report

This script generates formatted Excel (`.xlsx`) reports based on the output from the previous check script. The reports provide detailed information for each service, including:

## Service Availability Report

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

## Dependencies

- This script requires the `ImportExcel` PowerShell module.
- The script requires you to have run either the `2-AvailabilityCheck/Get-Region.ps1` or `3-CostInformation/Perform-RegionComparison.ps1` or both scripts to generate the necessary JSON input files for availability and cost data.

## Example

If you have created one or more availability JSON files using the `2-AvailabilityCheck/Get-Region.ps1` script, run the following commands, replacing the path with your actual file path(s):

```powershell
.\Get-Report.ps1 -availabilityInfoPath `@("..\2-AvailabilityCheck\Availability_Mapping_southeastasia.json", "..\2-AvailabilityCheck\Availability_Mapping_westeurope.json")` -costComparisonPath "..\3-CostInformation\region_comparison_prices.json"

```

The script generates an `.xlsx` file in the `7-report` folder, named `Availability_Report_CURRENTTIMESTAMP`.
