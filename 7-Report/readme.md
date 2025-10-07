# Export Script

This script generates formatted Excel (`.xlsx`)reports based on the output from the previous check script. The reports provide detailed information for each service, including:

## Service Availability Report

- **Resource type**
- **Resource count**
- **Implemented (origin) regions**
- **Implemented SKUs**
- **Selected (target) regions**
- **Availability in the selected regions**

## Cost Comparison Report

- **Azure Cost Meter ID**
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

## Usage Instructions

1. Open a PowerShell command line.
2. Navigate to the `7-Report` folder.
3. If you have created one or more availability JSON files using the `2-AvailabilityCheck/Get-Region.ps1` script, run the following commands, replacing the path with your actual file path(s):

    ```powershell
    .\Get-Report.ps1 -availabilityInfoPath `@("..\2-AvailabilityCheck\Availability_Mapping_Asia_Pacific.json", "..\2-AvailabilityCheck\Availability_Mapping_Europe.json")` -costComparisonPath "..\3-CostInformation\region_comparison_prices.json"
    ```
The script generates an `.xlsx` and `.csv` files in the `7-report` folder, named `Availability_Report_CURRENTTIMESTAMP`.
