<#
.SYNOPSIS
    Take a list of meter IDs and a list of regions, and return the pricing information for the
    equivalent Azure meters in those regions.
    Requires ImportExcel module if Excel output is requested.
    PS1> Install-Module -Name ImportExcel

.PARAMETER resourceFile
    A JSON file containing the resource cost information. This file is created by the Get-CostInformation.ps1 script.

.PARAMETER targetRregions
    An array of regions to compare.

.PARAMETER outputFormat
    The format of the output file. Supported formats are 'json', 'excel', 'csv' or 'console'. If not specified, output is written to the console.

.PARAMETER outputFilePrefix
    The prefix of the output file to be created. The extension will be added automatically based on the output format. Not used if outputFormat is 'console'.

.EXAMPLE
    .\Perform-RegionComparison.ps1 -regions @("eastus", "westeurope", "southeastasia")
#>

param (
    [string[]]$resourceFile = "resources.json",          # the JSON file containing the resource cost information
    [string[]]$regions,                                  # array of regions to compare
    [string]$outputFormat = "console",                   # json, excel or csv. If not specified, output is written to the console
    [string]$outputFilePrefix = "region_comparison"      # the output file prefix. Not used if outputFormat is not specified
)

function Write-ToFileOrConsole {
    param(
        [string]$outputFormat,
        [string]$outputFilePrefix,
        [object[]]$data,
        [string]$label
    )

    switch ($outputFormat) {
    "json" {
        $outputFilePrefix += "_$label"
        if ($outputFilePrefix -notmatch '\.json$') {
            $outputFilePrefix += ".json"
        }
        $data | ConvertTo-Json | Out-File -FilePath $outputFilePrefix -Encoding UTF8
        Write-Output "$($data.Count) rows written to $outputFilePrefix"
    }
    "csv" {
        $outputFilePrefix += "_$label"
        if ($outputFilePrefix -notmatch '\.csv$') {
            $outputFilePrefix += ".csv"
        }
        $data | Export-Csv -Path $outputFilePrefix -NoTypeInformation -Encoding UTF8
        Write-Output "$($data.Count) rows written to $outputFilePrefix"
    }
    "excel" {
        if ($outputFilePrefix -notmatch '\.xlsx$') {
            $outputFilePrefix += ".xlsx"
        }
        $data | Export-Excel -WorksheetName $label -TableName $label -Path .\$outputFilePrefix
        Write-Output "$($data.Count) rows written to tab $label of $outputFilePrefix"
    }
    Default {
        # Display the table in the console
        $data | Format-Table -AutoSize
    }
}

}

# Internal script parameters
#$ErrorActionPreference = "Stop"
#$VerbosePreference = "Continue"
$meterIdBatchSize = 10
$regionBatchSize = 10
$baseUri = "https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview"

# Input checking
# Check that the resource file exists
if (-not (Test-Path -Path $resourceFile)) {
    Write-Error "Resource file '$resourceFile' does not exist."
    exit 1
}

# Check that at least one region is specified
if ($null -eq $regions -or $regions.Count -eq 0) {
    Write-Error "At least one region must be specified."
    exit 1
}

# Check that the requested output format is valid
if ($outputFormat -notin @("json", "csv", "excel", "console")) {
    Write-Error "Output format '$outputFormat' is not supported. Supported formats are 'json', 'csv', 'excel', and 'console'."
    exit 1
}

# If output format is specified, check that the output file prefix is also specified
if ($null -ne $outputFormat -and $null -eq $outputFilePrefix -or $outputFilePrefix -eq "") {
    Write-Error "Output file prefix must be specified if output format is specified."
    exit 1
}

# If output format is excel, check that the ImportExcel module is installed
if ($outputFormat -eq "excel" -and -not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Error "ImportExcel module is not installed. Please install it using 'Install-Module -Name ImportExcel'."
    exit 1
}

# Read the resource file into a variable
$jsonContent = Get-Content -Path $resourceFile -Raw
$resourceData = $jsonContent | ConvertFrom-Json
if ($null -eq $resourceData -or $resourceData.Count -eq 0) {
    Write-Error "No data found in $resourceFile. Please run the Get-AzureServices.ps1 collection script first."
    exit 1
}

# Extract the unique meter IDs from the resource data
$meterIds = $resourceData.meterIds | Sort-Object -Unique
if ($null -eq $meterIds -or $meterIds.Count -eq 0) {
    Write-Error "No meter IDs found in $resourceFile. Please run the Get-AzureServices.ps1 collection script first."
    exit 1
}

Write-Verbose "Meter IDs: $($meterIds -join ', ')"
Write-Verbose "Regions: $($regions -join ', ')"

# Query the API using meterID as the filter to get the product ID and Meter Name
# For some services this will give unique results, but for others there may be multiple entries
# some meterIDs stretch across regions although this is unusual
# usually tierMinimumUnits is the most common reason for this

Write-Verbose "Querying pricing API for meter names and product IDs..."

$inputTable = @()

# Process meterIDs in batches to avoid URL length issues
for ($i = 0; $i -lt $meterIds.Count; $i += $meterIdBatchSize) {
    $batchMeterIds = $meterIds[$i..([math]::Min($i+$meterIdBatchSize-1, $meterIds.Count-1))]
    $filterString = '$filter=currencyCode eq ''USD'''
    $filterString += " and type eq 'Consumption'"
    $filterString += " and isPrimaryMeterRegion eq true"
    $filterString += " and (meterId eq '$($batchMeterIds -join "' or meterId eq '")')"

    Write-Verbose "Filter string in use is $filterString"

    $uri = "$baseUri&$filterString"

    $queryResult = Invoke-RestMethod -Uri $uri -Method Get

    if ($null -eq $queryResult) {
        Write-Error "Failed to retrieve data for the supplied meter IDs"
        exit 1
    }

    # The tierMinimumUnits property is used to indicate bulk discounts for the same meter ID
    # For comparison purposes we will use the lowest tierMinimumUnits value for each meter ID
    foreach ($item in $queryResult.Items | Select-Object meterId, meterName, productId, skuName, armRegionName, unitOfMeasure -Unique) {
        $row = [PSCustomObject]@{
            "MeterId"          = $item.meterId
            #"PreTaxCost"       = ($resourceData | Where-Object { $_.ResourceGuid -eq $item.meterId } | Measure-Object -Property PreTaxCost -Sum).Sum
            "MeterName"        = $item.meterName
            "ProductId"        = $item.productId
            "SkuName"          = $item.skuName
            "ArmRegionName"    = $item.armRegionName
            "TierMinimumUnits" = ($queryResult.Items | Where-Object { $_.meterId -eq $item.meterId }).tierMinimumUnits | Sort-Object | Select-Object -First 1
            "unitOfMeasure"   =  $item.unitOfMeasure
        }
        $inputTable += $row
    }
}

Write-ToFileOrConsole -outputFormat $outputFormat -outputFilePrefix $outputFilePrefix -data $inputTable -label "inputs"

# Using the input table, query the pricing API for each meterName+productId+skuName combination across the specified regions
Write-Output "Querying pricing API for region comparisons. Please be patient..."

$resultTable = @()

# Azure pricing has the unfortunate characteristic that some meter IDs have different units of measure in different regions.
# Instead of trying to handle this and convert between units, it is better to exclude them and flag them for manual processing.
$uomError = $false
$uomErrorTable = @()

$counter = 0
foreach ($inputRow in $inputTable) {
    $counter++
    Write-Progress -Activity "Processing meter IDs" -Status "Meter ID $counter of $($inputTable.Count)" -PercentComplete (($counter / $inputTable.Count) * 100)
    # Add the source region to the regions to get source pricing information
    $tempRegions = $regions + $inputRow.ArmRegionName | Sort-Object -Unique

    # Process regions in batches to avoid URL length issues
    for ($i = 0; $i -lt $tempRegions.Count; $i += $regionBatchSize) {
        $regionBatch = $tempRegions[$i..([math]::Min($i+$regionBatchSize-1, $tempRegions.Count-1))]

        $filterString = '$filter=currencyCode eq ''USD'''
        $filterString += " and type eq 'Consumption'"
        $filterString += " and isPrimaryMeterRegion eq true"
        $filterString += " and meterName eq '$($inputRow.MeterName)'"
        $filterString += " and productId eq '$($inputRow.ProductId)'"
        $filterString += " and skuName eq '$($inputRow.SkuName)'"
        $filterString += " and (armRegionName eq '$($regionBatch -join "' or armRegionName eq '")')"

        Write-Verbose "Filter string in use is $filterString"

        $uri = "$baseUri&$filterString"
        $queryResult = Invoke-RestMethod -Uri $uri -Method Get

        $batchProgress = [int][Math]::Truncate($i / 10) + 1
        Write-Verbose "Query for meter ID $($inputRow.MeterId) batch $batchProgress returned $($queryResult.Count) items"

        # Exclude rows with retail price zero
        $queryResult.Items = $queryResult.Items | Where-Object { $_.retailPrice -gt 0 }

        # If there are multiple entries for the same meterId, filter to only those with the same tierMinimumUnits as the original region
        $queryResult.Items = $queryResult.Items | Where-Object { $_.tierMinimumUnits -eq $inputRow.TierMinimumUnits }

        # Check if rows have a different unit of measure from the input row
        $uomCheck = $queryResult.Items | Where-Object { $_.unitOfMeasure -ne $inputRow.unitOfMeasure } | Select-Object meterId, unitOfMeasure
        if ($uomCheck.Count -gt 0) {
            $uomError = $true
            foreach ($item in $uomCheck) {
                $row = [PSCustomObject]@{
                    "OrigMeterID"   = $inputRow.MeterId
                    "OrigUoM"       = $inputRow.unitOfMeasure
                    "TargetMeterID" = $item.meterId
                    "TargetUoM"     = $item.unitOfMeasure
                }
                $uomErrorTable += $row
            }
        }

        # Remove rows where the unit of measure is different from the original
        $queryResult.Items = $queryResult.Items | Where-Object { $_.unitOfMeasure -eq $inputRow.unitOfMeasure }

        foreach ($item in $queryResult.Items) {
            $row = [PSCustomObject]@{
                "OrigMeterId"       = $inputRow.MeterId
                "OrigRegion"        = if ($inputRow.ArmRegionName -eq $item.armRegionName) { "X" }
                #"OrigCost"          = $inputRow.PreTaxCost
                "MeterId"           = $item.meterId
                "ServiceFamily"     = $item.serviceFamily
                "ServiceName"       = $item.serviceName
                "MeterName"         = $item.meterName
                "ProductId"         = $item.productId
                "ProductName"       = $item.productName
                "SkuName"           = $item.skuName
                "UnitOfMeasure"     = $item.unitOfMeasure
                "RetailPrice"       = $item.retailPrice
                "Region"            = $item.armRegionName
            }
            $resultTable += $row
        }
    }
}

# If there were any UoM errors, write them to the output
if ($uomError) {
    Write-Output "Warning: Different unit of measure detected between source and target region(s). These target meters will be excluded from the comparison."
    Write-Output "Please review the uomerrors output and handle these meters manually."
    Write-ToFileOrConsole -outputFormat $outputFormat -outputFilePrefix $outputFilePrefix -data $uomErrorTable -label "uomerrors"
}

# If at this point there are duplicate combinations of MeterName, ProductId, SkuName then
# this indicates that there are multiple target meters for the same region, which will cause issues later
$tempTable1 = $resultTable | Where-Object { $_.OrigRegion -eq "X" } | Select-Object -Property OrigMeterId, MeterName, ProductId, SkuName | Sort-Object
$tempTable2 = $tempTable1 | Sort-Object -Property OrigMeterId, MeterName, ProductId, SkuName -Unique

if ($tempTable1.Count -ne $tempTable2.Count) {
    Write-Error "There are duplicate target meters for the same region. Please report this issue to the script author."
    Write-ToFileOrConsole -outputFormat $outputFormat -outputFilePrefix $outputFilePrefix -data $resultTable -label "RegionComparison"
    exit
}

# For each row, add the percentage difference in retail price between the current row and the original region for that meter ID
foreach ($row in $resultTable) {
    $origPrice = ($resultTable | Where-Object { $_.OrigMeterId -eq $row.OrigMeterId -and $_.OrigRegion -eq "X" }).RetailPrice
    $row | Add-Member -MemberType NoteProperty -Name "PriceDiffToOrigin" -Value ($row.RetailPrice - $origPrice)
    if ($origPrice -ne 0) {
        $row | Add-Member -MemberType NoteProperty -Name "PercentageDiffToOrigin" -Value ([math]::Round((($row.RetailPrice - $origPrice) / $origPrice), 2))
        #$row | Add-Member -MemberType NoteProperty -Name "CostDiffToOrigin" -Value ([math]::Round(($row.PercentageDiffToOrigin * $row.OrigCost), 2))
    } else {
        $row | Add-Member -MemberType NoteProperty -Name "PercentageDiffToOrigin" -Value $null
        #$row | Add-Member -MemberType NoteProperty -Name "CostDiffToOrigin" -Value $null
    }
}

Write-ToFileOrConsole -outputFormat $outputFormat -outputFilePrefix $outputFilePrefix -data $resultTable -label "prices"

<# Future functionality - removed for now
# Construct a table showing the total possible savings for each target region
$savingsTable = @()
foreach ($region in $regions) {
    $totalOrigCost = ($resultTable | Where-Object { $_.OrigRegion -eq "X" }).OrigCost | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $regionSavings = ($resultTable | Where-Object { $_.Region -eq $region }).CostDiffToOrigin | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $percentageSavings = if ($totalOrigCost -ne 0) { [math]::Round(($regionSavings / $totalOrigCost), 4) } else { $null }
    $row = [PSCustomObject]@{
        "Region"               = $region
        "OriginalCost"         = [math]::Round($totalOrigCost, 2)
        "Difference"           = [math]::Round($regionSavings, 2)
        "PercentageDifference" = $percentageSavings
    }
    $savingsTable += $row
}

Write-ToFileOrConsole -outputFormat $outputFormat -outputFilePrefix $outputFilePrefix -data $savingsTable -label "savings"
#>

# Construct a summary table for only the original meterIDs and region that shows the cheapest region(s) and the price difference
$summaryTable = @()
foreach ($inputRow in $inputTable) {
    $origRow = $resultTable | Where-Object { $_.OrigMeterId -eq $inputRow.MeterId -and $_.OrigRegion -eq "X" }
    $origPrice = if ($null -ne $origRow) { $origRow.RetailPrice } else { $null }
    if ($null -ne $origRow) {
        $row = [PSCustomObject]@{
            "MeterId"               = $origRow.MeterId
            "MeterName"             = $origRow.MeterName
            "ProductName"           = $origRow.ProductName
            "SkuName"               = $origRow.SkuName
            "OriginalRegion"        = $origRow.Region
            "LowerPricedRegions"    = ($resultTable | Where-Object { $_.OrigMeterId -eq $inputRow.MeterId -and $_.RetailPrice -lt $origPrice }).Region -join ", "
            "SamePricedRegions"     = ($resultTable | Where-Object { $_.OrigMeterId -eq $inputRow.MeterId -and $_.RetailPrice -eq $origPrice -and $_.Region -ne $origRow.Region }).Region -join ", "
            "HigherPricedRegions"   = ($resultTable | Where-Object { $_.OrigMeterId -eq $inputRow.MeterId -and $_.RetailPrice -gt $origPrice }).Region -join ", "
        }
        $summaryTable += $row
    }
}

Write-ToFileOrConsole -outputFormat $outputFormat -outputFilePrefix $outputFilePrefix -data $summaryTable -label "pricemap"
Write-Output "Script completed successfully."