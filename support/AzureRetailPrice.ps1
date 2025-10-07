function Get-AzureRetailPrice {
    <#
    .SYNOPSIS
        Retrieve Azure Retail Prices from the Azure Retail Price API.
    .DESCRIPTION
        Query the Retail Rates Prices API to get retail prices for all Azure services.
        Reference: https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices
    .NOTES
        The function parameters represent the filter values that are documented with the API: https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices#api-filters
        Service Family can be one of: https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices#supported-servicefamily-values
    .LINK
        N/A
    .EXAMPLE
        Get-AzureRetailPrice -armSkuName Standard_B2ms -armRegionName swedencentral -priceType Consumption -serviceFamily Compute | FT -AutoSize
        
        - List all _consumption_ prices for _Standard_B2ms_ VMs in the _Sweden Central_ Azure Region
        - Format the output as a table with _AutoSize_
    .EXAMPLE
        Get-AzureRetailPrice -meterName 'P30 ZRS Disk' -productName 'Premium SSD Managed Disks' | Select-Object location, meterName, unitOfMeasure, retailPrice | Sort-Object retailPrice -Descending

        - List all prices for _PZ0 ZRS Disks_ across all Azure Regions
        - Limit the output to _location_, _meterName_, _unitOfMeasure_ and _retailPrice_
        - Sort _descending_ by _retailPrice_
        - GREAT for finding the cheapest region for a certain SKU
    .EXAMPLE
        Get-AzureRetailPrice -armSkuName Standard_M8ms -armRegionName eastus -priceType Reservation | ConvertTo-Json

        - List all _reservation_ prices for _Standard_M8ms_ VMs in the _East US_ Azure Region
        - Return them as json
    .EXAMPLE
        Get-AzureRetailPrice -armSkuName Standard_B2ms -armRegionName swedencentral -priceType Consumption -serviceFamily Compute | Out-File -FilePath 'C:\temp\AzureRetailPrices.json' -Force

        - List all _consumption_ prices for _Standard_B2ms_ VMs in the _Sweden Central_ Azure Region
        - Write the output to a file in JSON format
    #>    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [string]$armRegionName,
        [Parameter(Mandatory = $False)]
        [string]$location,
        [Parameter(Mandatory = $False)]
        [string]$meterId,
        [Parameter(Mandatory = $False)]
        [string]$meterName,
        [Parameter(Mandatory = $False)]
        [string]$productId,
        [Parameter(Mandatory = $False)]
        [string]$skuId,
        [Parameter(Mandatory = $False)]
        [string]$productName,
        [Parameter(Mandatory = $False)]
        [string]$skuName,
        [Parameter(Mandatory = $False)]
        [string]$serviceName,
        [Parameter(Mandatory = $False)]
        [string]$serviceId,
        [Parameter(Mandatory = $False)]
        [string]$serviceFamily,
        [Parameter(Mandatory = $False)]
        [string]$priceType,
        [Parameter(Mandatory = $False)]
        [string]$armSkuName,
        [Parameter(Mandatory = $False)]
        [string]$apiUrl = 'https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview',
        [Parameter(Mandatory = $False)]
        [string]$currencyCode = 'USD'
    )
    
    # Initialize Variables
    $query = ''
    $paramCounter = 1
    $restMethod = 'GET'
    $response = $null

    # Parameters check and generate filter
    if($PSBoundParameters.count -gt 0) {
        $PSBoundParameters.GetEnumerator() | ForEach-Object {
            if($PSBoundParameters.count -ne $paramCounter) {
                $query = $query + $_.Key + " eq '" + $_.Value + "' and "
            }
            else {
                $query = $query + $_.Key + " eq '" + $_.Value + "'"
            }
            $paramCounter += 1
        }

        $filter = "&currencyCode='" + $currencyCode + "'&`$filter=" + $query
    }
    else {
        $filter = "&currencyCode='" + $currencyCode + "'"
    }

    # Generate URL
    $requestUrl = $apiUrl + $filter

    # Query REST API until no further NextPageLink is returned.
    while ($requestUrl) {
        $temporaryResponse = Invoke-RestMethod -Method $restMethod -Uri $requestUrl
        $response += $temporaryResponse.Items
        $requestUrl = $temporaryResponse.NextPageLink
    }

    return $response
}