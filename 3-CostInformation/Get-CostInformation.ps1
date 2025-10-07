<#
.SYNOPSIS
    Take a collection of given resource IDs and return the cost incurred during previous months,
    grouped as needed. For this we use the Microsoft.CostManagement provider of each subscription.
    Requires Az.CostManagement module 0.4.2 or later.
    Requires ImportExcel module if Excel output is requested.
    PS1> Install-Module -Name Az.CostManagement
    PS1> Install-Module -Name ImportExcel

.PARAMETER startDate
    The start date of the period to be examined (default is the first day of the previous month)

.PARAMETER endDate
    The end date of the period to be examined (default is the last day of the previous month)

.PARAMETER resourceFile
    A JSON file containing the resources

.PARAMETER outputFile
    The stem of the output file to be created. The extension will be added automatically based on the output format. Not used if outputFormat is 'console'.

.PARAMETER outputFormat
    The format of the output file. Supported formats are 'json', 'csv', 'excel' and 'console'. Default is 'json'.

.PARAMETER testMode
    If set, only the first subscription ID will be used to retrieve a quick result set for testing purposes.

.EXAMPLE
    .\Get-CostInformation.ps1
    .\Get-CostInformation.ps1 -startDate "2023-01-01" -endDate "2023-06-30" -resourceFile "resources.json" -outputFile "resource_cost" -outputFormat "json"

#>

param (
    [string]$startDate    = (Get-Date).AddMonths(-1).ToString("yyyy-MM-01"),                    # the first day of the previous month
    [string]$endDate      = (Get-Date).AddDays(-1 * (Get-Date).Day).ToString("yyyy-MM-dd"),     # the last day of the previous month
    [string]$resourceFile = "resources.json",
    [string]$outputFile   = "resource_cost",
    [string]$outputFormat = "json",                # json, csv, excel or console
    [switch]$testMode
)

# Input checking
# Check that the resource file exists
if (-not (Test-Path -Path $resourceFile)) {
    Write-Error "Resource file '$resourceFile' does not exist."
    exit 1
}

# Check that the requested output format is valid
if ($outputFormat -notin @("json", "csv", "excel", "console")) {
    Write-Error "Output format '$outputFormat' is not supported. Supported formats are 'json', 'csv', 'excel', and 'console'."
    exit 1
}

# Check if the needed modules are installed
if (-not (Get-Module -ListAvailable -Name Az.CostManagement)) {
    Write-Error "Az.CostManagement module is not installed. Please install it using 'Install-Module -Name Az.CostManagement'."
    exit 1
}
if ($outputFormat -eq "excel" -and -not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Error "ImportExcel module is not installed. Please install it using 'Install-Module -Name ImportExcel'."
    exit 1
}

# Read the content of the workloads file
$jsonContent = Get-Content -Path $resourceFile -Raw

# Convert the JSON content to a PowerShell object
$workloads = $jsonContent | ConvertFrom-Json
$resourceTable = $workloads | Select-Object ResourceSubscriptionId, ResourceId

if ($testMode) {
    $subscriptionIds = @($subscriptionIds[0]) # For testing, use only the first subscription ID
}

# Query parameters
$timeframe = "Custom"
$type = "AmortizedCost"
$granularity = "Monthly"

$grouping = @(
    @{
        type = "Dimension"
        name = "ResourceId"
    },
    @{
        type = "Dimension"
        name = "PricingModel"
    },
    @{
        type = "Dimension"
        name = "MeterCategory"
    },
    @{
        type = "Dimension"
        name = "MeterSubcategory"
    },
    @{
        type = "Dimension"
        name = "Meter"
    },
    @{
        type = "Dimension"
        name = "ResourceGuid"
   }
)

$aggregation = @{
    PreTaxCost = @{
        type = "Sum"
        name = "PreTaxCost"
    }
}

$table = @()
$subscriptionIds = $resourceTable.ResourceSubscriptionId | Sort-Object -Unique

if ($subscriptionIds.Count -eq 1) {
    $subscriptionIds = @($subscriptionIds) # If only one subscription ID is found, use it as an array
}

# Group the resources by subscription and issue a cost management query for each subscription
# This reduces the number of API calls and allows us to handle multiple subscriptions efficiently.

for ($subIndex = 0; $subIndex -lt $subscriptionIds.Count; $subIndex++) {
    $scope = "/subscriptions/$($subscriptionIds[$subIndex])"

    $resourceIds = $resourceTable | Where-Object { $_.ResourceSubscriptionId -eq $subscriptionIds[$subIndex] } | Select-Object -ExpandProperty ResourceId
    Write-Output "Querying subscription $(${subIndex}+1) of $($subscriptionIds.Count): $($subscriptionIds[$subIndex])"

    $dimensions = New-AzCostManagementQueryComparisonExpressionObject -Name 'ResourceId' -Value $resourceIds
    $filter = New-AzCostManagementQueryFilterObject -Dimensions $dimensions

    $queryResult = Invoke-AzCostManagementQuery `
        -Scope $scope `
        -Timeframe $timeframe `
        -Type $type `
        -TimePeriodFrom $startDate `
        -TimePeriodTo $endDate `
        -DatasetAggregation $aggregation `
        -DatasetGrouping $grouping `
        -DatasetFilter $filter `
        -DatasetGranularity $granularity

    # Convert the query result into a table
    for ($i = 0; $i -lt $queryResult.Row.Count; $i++) {
        $row = [PSCustomObject]@{}
        for ($j = 0; $j -lt $queryResult.Column.Count; $j++) {
            # For column BillingMonth we output it as yyyy-MM
            if ($queryResult.Column.Name[$j] -eq "BillingMonth" -and $queryResult.Column.Type[$j] -eq "Datetime") {
                $value = Get-Date $queryResult.Row[$i][$j] -Format "yyyy-MM"
            } else {
                $value = $queryResult.Row[$i][$j]
            }
            $row | Add-Member -MemberType NoteProperty -Name $queryResult.Column.Name[$j] -Value $value
        }
        $table += $row
    }
}

# Output in the desired format
switch ($outputFormat) {
    "json" {
        if ($outputFile -notmatch '\.json$') {
            $outputFile += ".json"
        }
        $table | ConvertTo-Json | Out-File -FilePath $outputFile -Encoding UTF8
        Write-Output "$($table.Count) rows written to $outputFile"
    }
    "csv" {
        if ($outputFile -notmatch '\.csv$') {
            $outputFile += ".csv"
        }
        $table | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
        Write-Output "$($table.Count) rows written to $outputFile"
    }
    "excel" {
        if ($outputFile -notmatch '\.xlsx$') {
            $outputFile += ".xlsx"
        }
        $label = "CostInformation"
        $table | Export-Excel -WorksheetName $label -TableName $label -Path .\$outputFile
        Write-Output "$($table.Count) rows written to $outputFile"
    }
    Default {
        # Display the table in the console
        $table | Format-Table -AutoSize
    }
}
