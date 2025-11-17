<#.SYNOPSIS
    Assess Azure resources by querying Resource Graph and extracting specific properties or metadata.

.DESCRIPTION
    This script queries Azure Resource Graph to retrieve information about resources within a specified scope
    (single subscription, resource group, or multiple subscriptions). It processes the results to extract
    additional properties or metadata based on predefined configurations and outputs the results to a JSON file.

.PARAMETER scopeType
    Specifies the scope type to run the query against. Valid values are 'singleSubscription', 'resourceGroup',
    or 'multiSubscription'. Default is 'singleSubscription'.

.PARAMETER subscriptionId
    The subscription ID to run the query against. If not provided, the current Azure context's subscription ID is used.

.PARAMETER resourceGroupName
    The name of the resource group to run the query against. Only applicable when scopeType is 'resourceGroup'.

.PARAMETER workloadFile
    The path to a JSON file containing subscription details. Used for multi-subscription scenarios.

.PARAMETER fullOutputFile
    The name of the output file where the full results will be exported. Default is "resources.json".

.PARAMETER summaryOutputFile
    The name of the output file where the summary will be exported. Default is "summary.json".

.PARAMETER includeCost
    A boolean flag indicating whether to include cost report generation. Default is $false. Note that this requires the identity
    running the script to have permissions to access cost management APIs, i.e. Cost Management Contributor role.

.FUNCTION Get-SingleData
    Queries Azure Resource Graph for resources within a single subscription and retrieves all results,
    handling pagination if necessary.

.FUNCTION Get-Property
    Extracts a specific property from a given object and assigns it to a global variable.

.FUNCTION Get-rType
    Retrieves resource-specific metadata or properties based on a predefined JSON configuration file.

.FUNCTION Get-Data
    Processes extracted properties or executes commands to retrieve additional data for a resource.

.FUNCTION Get-Method
    Determines the appropriate method to retrieve resource-specific data based on the resource type and flag type.

.FUNCTION Invoke-CostReportSchedule
    Generates a cost report for a specified subscription by invoking the Azure REST API and retrieves cost details
    for the previous month.

.FUNCTION Get-CostReport
    Fetches the cost report details from the Azure REST API and processes the results.

.FUNCTION Get-MeterId
    Retrieves unique meter IDs associated with a specific resource ID from the cost details CSV.

.EXAMPLE
    PS C:\> .\Get-AzureServices.ps1 -scopeType singleSubscription -subscriptionId "12345678-1234-1234-1234-123456789abc"
    Runs the script for a single subscription with the specified subscription ID and outputs the results to the default file.

.EXAMPLE
    PS C:\> .\Get-AzureServices.ps1 -scopeType resourceGroup -resourceGroupName "MyResourceGroup"
    Runs the script for a specific resource group within the current subscription and outputs the results to the default file.

.EXAMPLE
    PS C:\> .\Get-AzureServices.ps1 -scopeType multiSubscription -workloadFile "subscriptions.json" -fullOutputFile "output.json"
    Runs the script for multiple subscriptions defined in the workload file and outputs the results to "output.json".


.OUTPUTS
    JSON file containing the queried resource data and extracted properties.

.NOTES
    - Requires Azure PowerShell module to be installed and authenticated.
    - Ensure the JSON configuration files (e.g., dataReplication.json, dataSize.json etc) are present in the "modules" directory.
    - Handles pagination for large datasets returned by Azure Resource Graph queries.
#>

param(
    [Parameter(Mandatory = $false)] [ValidateSet('singleSubscription', 'resourceGroup', 'multiSubscription')] [string] $scopeType = 'singleSubscription', # scope type to run the query against
    [Parameter(Mandatory = $false)] [string] $subscriptionId, # Subscription ID to run the query against
    [Parameter(Mandatory = $false)] [string] $resourceGroupName, # resource group to run the query against
    [Parameter(Mandatory = $false)] [string] $workloadFile, # JSON file containing subscriptions
    [Parameter(Mandatory = $false)] [string] $fullOutputFile = "resources.json", # Json file to export the results to
    [Parameter(Mandatory = $false)] [string] $summaryOutputFile = "summary.json", # Json file to export the results to
    [Parameter(Mandatory = $false)] [bool] $includeCost = $false # Include cost report
)

Function Get-SingleData {
    param(
        [Parameter(Mandatory = $true)] [string] $query
    )
    $resultSet = @()
    $response = Search-AzGraph -Query $query -First 1000
    $resultSet += $response
    # If a skip token is returned, there are more results to fetch
    while ($null -ne $response.SkipToken) {
        $response = Search-AzGraph -Query $query -First 1000 -SkipToken $response.SkipToken
        $resultSet += $response
    }
    $Script:baseresult = $resultSet
}

Function Get-MultiLoop {
    param(
        [Parameter(Mandatory = $true)] [string] $workloadFile
    )
    # Open workload file and get subscription IDs
    $workloads = Get-Content -Path $workloadFile -raw | ConvertFrom-Json
    $tempArray = @()
    foreach ($subscription in $workloads.subscriptions) {
        $basequery = "resources | where subscriptionId == '$subscription'"
        Get-SingleData -query $basequery
        $tempArray += $Script:baseresult
        If ($includeCost) {
            Invoke-CostReportSchedule -SubscriptionId $subscription
            Get-CostReport -PathForResult $pathForResult
            $tempCostArray += $Script:costdetails
        }
    }
    $Script:baseresult = $tempArray
    $Script:costdetails = $tempCostArray
}

Function Get-Property {
    param(
        [Parameter(Mandatory = $true)] [pscustomobject] $object,
        [Parameter(Mandatory = $true)] [string] $property,
        [Parameter(Mandatory = $true)] [string] $outputVarName
    )
    #Reset variable to avoid conflicts
    Set-Variable -Name $outputVarName -Value $null -scope script
    Set-Variable -Name $outputVarName -Value $object -scope script
    If ($property -match "\.+") {
        foreach ($part in $property -split '\.') {
            $object = $object.$part
        }
    }
    else {
        $object = $object.$property
    }
    Set-Variable -Name $outputVarName -Value $object -scope script
}

Function Invoke-CmdLine {
    param(
        [Parameter(Mandatory = $true)] [string] $cmdLine,
        [Parameter(Mandatory = $true)] [string] $outputVarName
    )
    #Reset variable to avoid conflicts
    Set-Variable -Name $outputVarName -Value $null -scope script
    $scriptBlock = [scriptblock]::Create($cmdLine)
    $cmdResult = & $scriptBlock
    # if result is a number linmit to 2 decimal places
    if ($cmdResult -is [int] -or $cmdResult -is [double]) {
        $cmdResult = "{0:N2}" -f $cmdResult
    }
    Set-Variable -Name $outputVarName -Value $cmdResult -Scope Script
}

function Get-rType {
    param (
        [Parameter(Mandatory = $true)] [string] $filePath,
        [Parameter(Mandatory = $true)] [pscustomobject] $object,
        [Parameter(Mandatory = $true)] [string] $outputVarName,
        [Parameter(Mandatory = $true)] [string] $resourceType
    )
    $json = Get-Content -Path $filePath | ConvertFrom-Json -depth 100
    $propertyExists = $json | Where-Object { $psItem.resourceType -eq $resourceType } | Select-Object -ExpandProperty isContainedInOriginalGraphOutput
    if ($propertyExists) {
        #"Property for $outputVarName for $resourceType indicated in $filePath"
        $property = $json | Where-Object { $psItem.resourceType -eq $resourceType } | Select-Object -ExpandProperty property
        # check if property is an array
        If ($property -is [system.array] -or $property -is [System.Management.Automation.PSCustomObject]) {
            $outputVar = @()
            foreach ($item in $property) {
                $varName = $item.PSObject.Properties.Name
                $varProp = $item.PSObject.Properties.Value
                # if property is an array, get each property
                Get-Property -object $object -property $varProp -outputVarName $varName
                # create a hash table containing the variable name and its value
                $outputVar += @{ $varName = Get-Variable -Name $varName -ValueOnly }
            }
            Set-Variable -Name $outputVarName -Value $outputVar -scope script
        }
        Else { Get-Property -object $object -property $property -outputVarName $outputVarName }
    }
    elseif ($propertyExists -eq $false) {
        #"Property for $outputVarName for $resourceType not indicated in $filePath, try to get cmdLine"
        $cmdLine = $json | Where-Object { $psItem.resourceType -eq $resourceType } | Select-Object -ExpandProperty cmdLine
        Invoke-CmdLine -cmdLine $cmdLine -outputVarName $outputVarName
    }
    else {
        #"Neither property nor cmdline for $outputVarName for $resourceType is indicated in $filepath"
        Set-Variable -Name $outputVarName -Value "N/A" -Scope Script
    }
}

Function Get-Method {
    Param(
        [Parameter(Mandatory = $true)] [string] $resourceType,
        [Parameter(Mandatory = $true)][ValidateSet('resiliencyProperties', 'dataSize', "ipConfig", "Sku")] [string] $flagType,
        [Parameter(Mandatory = $true)] [pscustomobject] $object
    )
    switch ($flagType) {
        'resiliencyProperties' { Get-rType -filePath .\modules\resiliencyProperties.json -object $object -outputVarName "resiliencyProperties" -resourceType $resourceType }
        'dataSize' { Get-rType -filePath .\modules\dataSize.json -object $object -outputVarName "dataSize" -resourceType $resourceType }
        'ipConfig' { Get-rType -filePath .\modules\ipConfig.json -object $object -outputVarName "ipAddress" -resourceType $resourceType }
        'Sku' { Get-rType -filePath .\modules\sku.json -object $object -outputVarName "sku" -resourceType $resourceType }
    }
}

Function Invoke-CostReportSchedule {
    param (
        [Parameter(Mandatory = $true)] [string]$SubscriptionId
    )
    $uri = "https://management.azure.com/subscriptions/$($SubscriptionId)/providers/Microsoft.CostManagement/generateCostDetailsReport?api-version=2025-03-01"
    $startDate = (Get-Date).AddDays(-1)
    $endDate = (Get-Date)
    # Define the request body
    $body = @{
        metric     = "AmortizedCost"
        timePeriod = @{
            start = $startDate.ToString("yyyy-MM-dd")
            end   = $endDate.ToString("yyyy-MM-dd")
        }
    }
    #Convert the body to JSON
    $bodyJson = $body | ConvertTo-Json
    $result = invoke-AzRestMethod -Uri $uri -Method POST -Payload $bodyJson
    $pathForResult = "https://management.azure.com" + $result.Headers.Location.AbsolutePath + "?api-version=2025-03-01"
    write-output "Cost report request submitted. Path for result: $pathForResult"
    Set-Variable -Name 'pathForResult' -Value $pathForResult -Scope Script
}

Function Get-CostReport {
    param (
        [Parameter(Mandatory = $true)] [string]$PathForResult
    )
    $i = 0
    $details = Invoke-AzRestMethod -uri $PathForResult -Method GET
    # Loop until $details.statuscode is 200
    while ($details.StatusCode -eq 202) {
        Start-Sleep -Seconds 10
        $i = $i + 10
        $details = Invoke-AzRestMethod -uri $PathForResult -Method GET
        Write-Output "Waiting for the cost report to be ready. Elapsed time: $i seconds"
    }
    "Cost report is ready. Downloading the report..."
    $subscriptionID = (($details.Content | ConvertFrom-Json).manifest.requestContext.requestScope) -replace "^/subscriptions/", "" -replace "/$", ""
    $blobLink = ($details.Content | ConvertFrom-Json).manifest.blobs.bloblink
    $blobContent = Invoke-RestMethod -Uri $blobLink -Method Get
    $blobContent | out-file "$subscriptionID.csv"
    $csv = Import-Csv -Path "$subscriptionID.csv"
    Set-Variable -name costdetails -Value $csv -Scope Script
}

Function Get-MeterId {
    param (
        [Parameter(Mandatory = $true)] [string]$ResourceId,
        [Parameter(Mandatory = $true)] [PSCustomObject]$csvObject
    )
    $outputArray = @()
    #Reset variable to avoid conflicts
    Set-Variable -Name 'meterIds' -Value @() -scope script
    $resMeterIds = $csvObject | Where-Object { $_.resourceId -eq $ResourceId } | Select-Object meterId -Unique
    # For each meterId, get the meterId value and add it to the output array
    foreach ($meterId in $resMeterIds) {
        $outputArray += $meterId.meterId
    }
    Set-Variable -Name 'meterIds' -Value $outputArray -Scope Script
}


# Main script starts here
# Turn off breaking change warnings for Azure PowerShell, for Get-AzMetric CmdLet
Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true
$outputArray = @()

Switch ($scopeType) {
    'singleSubscription' {
        $baseQuery = "resources"
        if (!$subscriptionId) {
            $subscriptionId = (Get-AzContext).Subscription.id
        }
        $baseQuery = "resources | where subscriptionId == '$subscriptionId'"
        Get-SingleData -query $baseQuery
        If ($includeCost) {
            # Generate cost report for the subscription
            Invoke-CostReportSchedule -SubscriptionId $subscriptionId
            Get-CostReport -PathForResult $pathForResult
        }
    }
    'resourceGroup' {
        # KQL Query to get all resources in a specific resource group and subscription
        if (!$subscriptionId) {
            $subscriptionId = (Get-AzContext).Subscription.id
        }
        $baseQuery = "resources | where resourceGroup == '$resourceGroupName' and subscriptionId == '$subscriptionId'"
        Get-SingleData -query $baseQuery
        If ($includeCost) {
            # Generate cost report for the subscription
            Invoke-CostReportSchedule -SubscriptionId $subscriptionId
            Get-CostReport -PathForResult $pathForResult
        }
    }
    'multiSubscription' {
        "multiple subscriptions"
        Get-MultiLoop -workloadFile $workloadFile
    }
}
$baseResult | ForEach-Object {
    $resourceType = $PSItem.type
    $resourceName = $PSItem.name
    $resourceLocation = $PSItem.location
    $resourceSubscriptionId = $PSItem.subscriptionId
    $resourceID = $PSItem.id
    $resourceZones = $PSItem.zones
    if ($PSItem.sku -ne $null) {
        $sku = $PSItem.sku
    }
    elseif ($PSItem.properties.sku -ne $null) {
        $sku = $PSItem.properties.sku
    }
    else {
        Get-Method -resourceType $resourceType -flagType "Sku" -object $PSItem
    }
    # if $sku is a single string and is not N/A then turn it into an object with name and the current sku value
    if ($sku -is [string] -and $sku -ne "N/A") {
        $tempSku = [PSCustomObject]@{
            name = $sku
        }
        $sku = $tempSku
    }
    $json = Get-Content -Path .\modules\sku.json | ConvertFrom-Json -depth 100
    $excludeList = $json | Where-Object { $_.resourceType -eq $resourceType -and $_.excludeFromReport -ne $null }
    if ($excludeList) {
        foreach ($excludeProp in $excludeList.excludeFromReport) {
            $sku.PSObject.Properties.Remove($excludeProp)
        }
    }
    Get-Method -resourceType $resourceType -flagType "resiliencyProperties" -object $PSItem
    Get-Method -resourceType $resourceType -flagType "dataSize" -object $PSItem
    Get-Method -resourceType $resourceType -flagType "ipConfig" -object $PSItem
    $outObject = [PSCustomObject] @{
        ResourceType           = $resourceType
        ResourceName           = $resourceName
        ResourceLocation       = $resourceLocation
        ResourceSubscriptionId = $resourceSubscriptionId
        ResourceID             = $resourceID
        ResourceSku            = $sku
        ResourceZones          = $resourceZones
        resiliencyProperties   = $resiliencyProperties
        dataSizeGB             = $dataSize
        ipAddress              = $ipAddress
        meterIds               = @()
    }
    If ($includeCost) {
        Get-MeterId -ResourceId $resourceId -csvObject $costDetails
        # add meterIds to the output object
        $outObject.meterIds += $meterIds
    }
    $outputArray += $outObject
}
$outputArray | ConvertTo-Json -Depth 100 | Out-File -FilePath $fullOutputFile
$groupedResources = $outputArray | Group-Object -Property ResourceType
$summary = @()
foreach ($group in $groupedResources) {
    $resourceType = $group.Name
    $uniqueMeterIds = $group.Group | Select-Object -Property meterIds -Unique | Select-Object -ExpandProperty meterIds
    $uniqueMeterIds = $uniqueMeterIds | Select-Object -Unique
    if ($uniqueMeterIds -isnot [System.Array]) {
        $uniqueMeterIds = @($uniqueMeterIds)
    }
    $uniqueLocations = $group.Group | Select-Object -Property ResourceLocation -Unique | Select-Object -ExpandProperty ResourceLocation
    if ($uniqueLocations -isnot [System.Array]) {
        $uniqueLocations = @($uniqueLocations)
    }
    If ($group.Group.ResourceSku -ne 'N/A') {

        $uniqueSkus = $group.Group.ResourceSku | Select-Object * -Unique
        if ( $uniqueSkus -isnot [System.Array]) {
            $uniqueSkus = @($uniqueSkus)
        }
        $summary += [PSCustomObject]@{ResourceCount = $group.Count; ResourceType = $resourceType; ImplementedSkus = $uniqueSkus; ImplementedRegions = $uniqueLocations; meterIds = $uniqueMeterIds }
    }
    Else {
        $summary += [PSCustomObject]@{ResourceCount = $group.Count; ResourceType = $resourceType; ImplementedSkus = @("N/A"); ImplementedRegions = $uniqueLocations; meterIds = $uniqueMeterIds }
    }
}
$summary | ConvertTo-Json -Depth 100 | Out-File -FilePath $summaryOutputFile