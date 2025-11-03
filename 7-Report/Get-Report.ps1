<#
.SYNOPSIS
    Exports Azure resource availability and cost comparison between regions to Excel

.DESCRIPTION
    Reads the output from 2-AvailabilityCheck/Get-Region.ps1 and 3-CostInformation/Perform-RegionComparison.ps1, structures it, and
    exports to an Excel file, including SKU details.

.PARAMETER availabilityInfoPath
    Array of paths to JSON files containing availability information.
.PARAMETER costComparisonPath
    Path to the JSON file containing cost comparison information.
#>

param(
    [Parameter(Mandatory = $false)][array]$availabilityInfoPath,
    [Parameter(Mandatory = $false)][string]$costComparisonPath
)

Function Set-ColumnColor {
    param(
        [Parameter(Mandatory = $true)] [object]$startColumn,
        [Parameter(Mandatory = $true)] [string[]]$cellValGreen,
        [Parameter(Mandatory = $true)] [string[]]$cellValRed,
       [Parameter(Mandatory = $false)] [string[]]$cellValYellow
    )
    $colCount = $ws.Dimension.End.Column
    for ($col = $startColumn; $col -le $colCount; $col++) {
        $colLetter = [OfficeOpenXml.ExcelCellAddress]::GetColumnLetter($col)
        $cell = $ws.Cells["$colLetter$row"]
        if ($cell.Value -in $cellValGreen) {
            $cell.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $cell.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightGreen)
        }
        elseif ($cell.Value -in $cellValRed) {
            $cell.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $cell.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::Coral)
        }
        elseif ($cell.Value -in $cellValYellow) {
            $cell.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $cell.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::Orange)
        }
    }
}

Function New-Worksheet {
    param (
        [Parameter(Mandatory = $true)][string]$WorksheetName,
        [Parameter(Mandatory = $true)][int]$LastColumnNumber,
        [Parameter(Mandatory = $true)][array]$reportData,
        [Parameter(Mandatory = $false)][int]$startColumnNumber,
        [Parameter(Mandatory = $false)][string[]]$cellValGreen,
        [Parameter(Mandatory = $false)][string[]]$cellValRed,
        [Parameter(Mandatory = $false)][string[]]$cellValYellow
    )
    $excelParams = @{
        Path          = $xlsxFileName
        WorksheetName = $WorksheetName
        AutoSize      = $true
        TableStyle    = 'None'
        PassThru      = $true
    }
    $excelPkg = $reportData | Select-Object -Property $allProps | Export-Excel @excelParams
    $ws = $excelPkg.Workbook.Worksheets[$WorksheetName]
    $lastColLetter = [OfficeOpenXml.ExcelCellAddress]::GetColumnLetter($lastColumnNumber)
    $headerRange = $ws.Cells["A1:$lastColLetter`1"]
    $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
    $headerRange.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::RoyalBlue)
    $headerRange.Style.Font.Color.SetColor([System.Drawing.Color]::White)
    for ($row = 2; $row -le ($reportData.Count + 1); $row++) {
        # Call the function to set column colors based on cell values
        If ($startColumnNumber) {
            Set-ColumnColor -startColumn $startColumnNumber -cellValGreen $cellValGreen -cellValRed $cellValRed -cellValYellow $cellValYellow
        }
    }
    $excelPkg.Save()
    "Sheet '$WorksheetName' with $($reportData.Count) entries added to '$xlsxFileName'."
}

# Collect all property names in first-seen order
Function Get-Props {
    param (
        [array]$data
    )
    $allProps = @()
    foreach ($obj in $data) {
        foreach ($p in $obj.PSObject.Properties.Name) {
            if ($allProps -notcontains $p) {
                $allProps += $p
            }
        }
    }
    return $allProps
}

Function Set-SvcAvailReportObj {
    param (
        [string]$resourceType,
        [int]$resourceCount,
        [array]$implementedRegions,
        [string]$sku,
        [string]$skuAvailability,
        [string]$serviceAvailability
    )
    if($skuAvailability -eq "true") {
        $skuAvailability = "Available"
        }
    elseif($skuAvailability -eq "false") {
        $skuAvailability = "Not available"
    }
    elseif($skuAvailability -eq "") {
        $skuAvailability = "NotCoveredByScript"
    }
    
    $reportItem = [PSCustomObject]@{
        ResourceType                         = $resourceType
        ResourceCount                        = $resourceCount
        ImplementedRegions                   = ($implementedRegions -join ", ")
        sku                                  = $sku
        "SKU available"                      = $skuAvailability
        "Service available"                  = $serviceAvailability
    }
    return $reportItem
}

#Define output file name with current timestamp (yyyyMMdd_HHmmss)
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$xlsxFileName = "Availability_Report_$timestamp.xlsx"

If ($availabilityInfoPath) {
    # Consider splitting into functions for better readability and maintainability
    $reportData = @()
    foreach ($path in $availabilityInfoPath) {
        $rawdata = Get-Content $path | ConvertFrom-Json -Depth 10
        foreach ($item in $rawdata) {
            $resourceType = $item.ResourceType
            $itemCount = $item.ResourceCount
            $regionAvailability = "Not available"
            $regionHeader = $item.SelectedRegion.region
            If ($item.SelectedRegion.available -eq "true") {
                $regionAvailability = "Available"
            }
            # if implementedSkus is exists and is not null
            if ($item.ImplementedSkus -and $item.ImplementedSkus[0] -ne "N/A") {
                ForEach ($sku in $item.SelectedRegion.SKUs) {
                    $reportItem = Set-SvcAvailReportObj -resourceType $resourceType -resourceCount $itemCount -implementedRegions $item.ImplementedRegions -sku $sku.skuname -skuAvailability $sku.available -serviceAvailability $regionAvailability
                    $reportData += $reportItem
                }
            }
            else {
                $reportItem = Set-SvcAvailReportObj -resourceType $resourceType -resourceCount $itemCount -implementedRegions $item.ImplementedRegions -sku "N/A" -skuAvailability "N/A" -serviceAvailability $regionAvailability
                $reportData += $reportItem
            }
        }
    }
}

$WorksheetName = "ServiceAvailability"
$allProps = Get-Props -data $reportData
$lastColumnNumber = $allProps.Count
New-Worksheet -WorksheetName $WorksheetName -LastColumnNumber $lastColumnNumber -reportData $reportData -startColumnNumber 5 -cellValGreen @("Available", "N/A") -cellValRed @("Not available") -cellValYellow @("NotCoveredByScript")

If ($costComparisonPath) {
    $rawdata = Get-Content $costComparisonPath | ConvertFrom-Json -Depth 10
    $costReportData = @()
    $uniqueMeterIds = $rawdata | Select-Object -Property OrigMeterId -Unique
    foreach ($meterId in $uniqueMeterIds) {
        $meterId = $meterId.OrigMeterId
        # get all occurrences of this meterId in $rawdata
        $meterOccurrences = $rawdata | Where-Object { $_.OrigMeterId -eq $meterId }
        $basedata = $meterOccurrences | Select-Object -Property ServiceName, MeterName, ProductName, SKUName -Unique
        $serviceName = $basedata.ServiceName
        $meterName = $basedata.MeterName
        $productName = $basedata.ProductName
        $skuName = $basedata.SKUName
        $pricingObj = [PSCustomObject]@{}
        foreach ($occurrence in $meterOccurrences) {
            $region = $occurrence.Region
            if ($null -eq $region -or $region -eq "") {
                $region = "Global"
            }
            $retailPrice = $occurrence.RetailPrice
            $pricingObj | Add-Member -MemberType NoteProperty -Name "$region-RetailPrice" -Value $retailPrice -Force
        }
        # Create a new object for each unique meter ID
        $costReportItem = [PSCustomObject]@{
            MeterId     = $meterId
            ServiceName = $serviceName
            MeterName   = $meterName
            ProductName = $productName
            SKUName     = $skuName
        }
        Foreach ($key in $pricingObj.PSObject.Properties.Name) {
            $costReportItem | Add-Member -MemberType NoteProperty -Name $key -Value $pricingObj.$key
        }
        # Add the cost report item to the report data array
        $costReportData += $costReportItem
    }
    $WorksheetName = "CostComparison"
    $allProps = Get-Props -data $costReportData
    $lastColumnNumber = $allProps.Count
    New-Worksheet -WorksheetName $WorksheetName -LastColumnNumber $lastColumnNumber -reportData $costReportData
}
