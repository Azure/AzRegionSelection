<#.SYNOPSIS
    This script evaluates the availability of Azure providers and SKUs across multiple regions by querying
    Azure Resource Graph to retrieve specific properties and metadata. The extracted data will then be
    analyzed and compared against the customer's current implementation to identify potential regions suitable
    for migration.

.DESCRIPTION
    This script assesses the availability of Azure services, resources, and SKUs across multiple regions.
    By integrating its output with the data collected from the 1-Collect script, it delivers a comprehensive
    analysis of potential migration destinations, identifying suitable regions and highlighting factors that
    may impact feasibility, such as availability constraints specific to each region. All extracted data,
    including availability details and region-specific insights, will be systematically stored in JSON files
    for further evaluation and decision-making.

.EXAMPLE
    PS C:\> .\Get-AvailabilityInformation.ps1
    Runs the script and outputs the results to the default files.

.OUTPUTS
    Availability_Mapping.json
    Mapping of all currently implemented resources and their SKUs, to Azure regions with availabilities.


.NOTES
    - Requires Azure PowerShell module to be installed and authenticated.
#>
param(
    [Parameter(Mandatory = $false)][string]$SummaryFilePath = "$(Get-Location)\..\1-Collect\summary.json"
)

function Out-JSONFile {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Data,
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )
    # This function writes the provided data to a JSON file at the specified path.
    Write-Output "  Writing data to file: $FileName" | Out-Host
    $Data | ConvertTo-Json -Depth 100 | Out-File -FilePath "$(Get-Location)\$FileName" -Force
}

Function Convert-LocationsToRegionCodes {
    param (
        [Parameter(Mandatory)][Object]$Data,
        [Parameter(Mandatory)][hashtable]$RegionMap
    )
    # Build reverse lookup (display name -> key)
    $ReverseMap = @{}
    foreach ($k in $RegionMap.Keys) { $ReverseMap[$RegionMap[$k].ToLower()] = $k }
    foreach ($item in $Data) {
        foreach ($rt in $item.ResourceTypes) {
            if ($rt.Locations) {
                $rt.Locations = @(
                    $rt.Locations | ForEach-Object {
                        $lk = $_.ToLower()
                        if ($ReverseMap.ContainsKey($lk)) { $ReverseMap[$lk] } else { $_ }
                    }
                )
            }
        }
    }
    return $Data
}


Function Import-Provider {
    param (
        [Parameter(Mandatory = $true)][string]$uriRoot
    )
    # This function retrieves all available Azure providers and their resource types, including locations.
    Write-Output "Retrieving all available providers" | Out-Host
    $Response = (Invoke-AzRestMethod -Uri "$uriRoot/providers?api-version=2021-04-01" -Method Get).Content | ConvertFrom-Json -depth 100
    
    # Transform the response to the desired structure and remove unwanted properties
    $Providers = foreach ($provider in $Response.value) {
        # Build an array of resource types using plain hashtables
        $rtArray = @()
        foreach ($rt in $provider.resourceTypes) {
            $rtArray += @{
                Type      = $rt.resourceType
                Locations = $rt.locations
            }
        }
        # Return a hashtable for each provider
        @{
            Namespace     = $provider.namespace
            ResourceTypes = $rtArray
        }
    }
    # Convert location display names to region codes using the provided region map
    $Providers = Convert-LocationsToRegionCodes -Data $Providers -RegionMap $Regions_All.Map
    # Save providers to a JSON file
    Out-JSONFile -Data $Providers -fileName "Azure_Providers.json"
    return @{
        Data = $Providers
    }
}

function Import-Region {
    # This function retrieves all Azure regions, sorts them alphabetically, flattens metadata to the top level, and removes PII information.
    Write-Output "  Retrieving regions information" | Out-Host
    $Response = (Invoke-AzRestMethod -Uri "$uriRoot/locations?api-version=2022-12-01" -Method Get).Content | ConvertFrom-Json -depth 100
    # Sort regions alphabetically by displayName
    $Response.value = $Response.value | Sort-Object displayName
    # Flatten metadata to the top level and remove PII information
    $ConsolidatedRegions = @()
    $TotalRegions = $Response.value.Count
    $CurrentRegionIndex = 0
    foreach ($Region in $Response.value | where { $_.metadata.regionType -eq "Physical" }) {
        #Write-Output "$($region.name) is regionType: $($region.metadata.regionType)" | out-host}
        $CurrentRegionIndex++
        Write-Output ("    Removing information for region {0:D03} of {1:D03}: {2}" -f $CurrentRegionIndex, $TotalRegions, $Region.displayName) | Out-Host
        if ($Region.metadata ) {
            $region.metadata.regionType -eq "Physical"
            # Remove subscription ID from pairedRegion and just keep the region name
            if ($Region.metadata.pairedRegion) {
                $Region.metadata.pairedRegion = $Region.metadata.pairedRegion | ForEach-Object { $_.name }
            }
            # Lift all properties from metadata to the top level
            foreach ($key in $Region.metadata.PSObject.Properties.Name) {
                $Region | Add-Member -MemberType NoteProperty -Name $key -Value $Region.metadata.$key -Force
            }
        }
        # Rebuild the object without metadata and id
        $newRegion = $Region | Select-Object * -ExcludeProperty metadata, id
        $ConsolidatedRegions += $newRegion
    }
    $Response.value = $ConsolidatedRegions
    # Create a mapping of region names to display names, this will be used later to replace region names with display names.
    $RegionMap = @{}
    $shortList = @()
    foreach ($Location in $Response.value) {
        $RegionMap[$Location.name] = $Location.displayName
        $shortlist += $location.name
    }
    # Save regions to a JSON file
    #Out-JSONFile -Data $Response -fileName "Azure_Regions.json"
    return @{
        Regions   = $Response
        Map       = $RegionMap
        ShortList = $shortList
    }
}

Function Get-ResourceTypeParameters {
    param (
        [Parameter(Mandatory = $true)][string]$ResourceType
    )
    # This function retrieves the parameters for a given resource type from the property maps.
    $propertyMapJson = Get-Content -path ".\propertymaps\propertyMaps.json" | ConvertFrom-Json
    $propertyExists = $propertyMapJson | Where-Object { $psitem.resourceType -eq $ResourceType }
    if ($propertyExists) {
        Return $propertyExists
    }
}

function Compare-ObjectsStrict {
    param(
        [psobject]$Object1,
        [psobject]$Object2,
        [string[]]$ExcludeProperty = @("count")
    )
    Write-Verbose "Entering Compare-ObjectsStrict"
    # Filter out excluded properties
    $props1 = $Object1.PSObject.Properties | Where-Object { $ExcludeProperty -notcontains $_.Name }
    $props2 = $Object2.PSObject.Properties | Where-Object { $ExcludeProperty -notcontains $_.Name }
    $norm1 = ($props1 | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ';'
    $norm2 = ($props2 |
        Sort-Object Name |
        ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ';'
    Write-Verbose "Comparing objects:"
    Write-Verbose "  Object1 (norm): $norm1"
    Write-Verbose "  Object2 (norm): $norm2"
    Write-Verbose "  Match: $($norm1 -eq $norm2)"
    return $norm1 -eq $norm2
}


Function Get-Property {
    param(
        [Parameter(Mandatory)][pscustomobject]$object,
        [Parameter(Mandatory)][pscustomobject]$PropertyNames,
        [Parameter(Mandatory)][pscustomobject]$outputObject
    )
    foreach ($key in $PropertyNames.PSObject.Properties.Name) {
        $sourceProp = $PropertyNames.$key
        $value = $object.$sourceProp
        $outputObject[$key] = $value
    }
    return $outputObject
}

Function Expand-NestedCollection {
    param(
        [Parameter(Mandatory)]$InputObjects,
        [Parameter(Mandatory)][pscustomobject]$Schema
    )
    $lSkus = @()
    $InputObjects | ForEach-Object {
        # Navigate down to the parent
        $parentObj = $PSItem
        for ($i = 0; $i -lt $Schema.startPath.Count; $i++) {
            $parentObj = $parentObj.$($Schema.startPath[$i])
        }
        foreach ($o in $parentObj) {
            If (!$Schema.ChildProperties -and $Schema.TopLevelProperties.Count -ge 1) {
                $props = @{}
                $props = get-Property -object $o -PropertyNames $Schema.TopLevelProperties -outputObject $props
                $lSkus += $props
            }
            elseif ($Schema.ChildProperties -and $Schema.TopLevelProperties.Count -ge 1) {
                $props = @{}
                $props = get-Property -object $o -PropertyNames $Schema.TopLevelProperties -outputObject $props
                $children = $parentObj
                for ($i = 0; $i -lt $Schema.ChildProperties.name.Count; $i++) {
                    $children = $children.$($Schema.ChildProperties.name[$i])
                }
                foreach ($child in $children) {
                    $childProps = $props.Clone()
                    $childProps = get-Property -object $child -PropertyNames $Schema.ChildProperties.props -outputObject $childProps
                    $lSkus += $childProps
                }
            }
        }
        $script:SKUs = $lSkus
    } 
}

Function Get-ResourceType {
    param (
        [Parameter(Mandatory = $true)][string]$ResourceType
    )
    $resourceObject = New-Object psobject
    Add-Member -InputObject $resourceObject -MemberType NoteProperty -Name "ResourceType" -Value $ResourceType
    $resourceProps = Get-ResourceTypeParameters -ResourceType $ResourceType
    if ($resourceProps) {
        "Processing resource type: $ResourceType"
        $outputFile = ($ResourceType -replace '[./]', '_') + ".json"
        $uri01 = $resourceProps.uri
        $regionalApiCall = $resourceProps.regionalApi
        $propertyFilter = $resourceProps.properties
        $script:SKUs = @()
        $outArray = @()
        If ($regionalApiCall) {
            Foreach ($region in $Regions_All.ShortList) {
                $baseObject = New-Object psobject
                Add-Member -InputObject $baseObject -MemberType NoteProperty -Name "regionCode" -Value $region
                $uri = $uri01 -f $subscriptionId, $region
        
                "Invoke-AzRestMethod -Uri $uri -Method Get"
                $Response = (Invoke-AzRestMethod -Uri $uri -Method Get).Content | ConvertFrom-Json -depth 100
                If ($response.error.code -ne 'NoRegisteredProviderFound') {
                    # Handle cases where the response might be wrapped in a 'Value' property
                    if ($Response.PSObject.Properties.Name -contains 'Value') {
                        $Response = $Response.Value
                    }
                    Expand-NestedCollection -InputObjects $response -Schema $propertyFilter
                    Add-Member -InputObject $baseObject -MemberType NoteProperty -Name "skus" -Value $Skus 
                }
                else {
                    "No SKUs found for region $region"
                    $baseObject | Add-Member -MemberType NoteProperty -Name "skus" -Value @()
                }
                $outArray += $baseObject
            } 
        }
        Else {
            "This api call gets all skus for all regions in one call"
            $uri = $uri01 -f $subscriptionId
            "Invoke-AzRestMethod -Uri $uri -Method Get"
            $Response = (Invoke-AzRestMethod -Uri $uri -Method Get).Content | ConvertFrom-Json -depth 100
            if ($Response.PSObject.Properties.Name -contains 'Value') {
                $Response = $Response.Value
            }
            Foreach ($region in $Regions_All.ShortList) {
                $baseObject = New-Object psobject
                Add-Member -InputObject $baseObject -MemberType NoteProperty -Name "regionCode" -Value $region
                $skusForRegion = $Response | Where-Object { $_.locations -contains $region }
                If ($skusForRegion) {
                    Expand-NestedCollection -InputObjects $skusForRegion -Schema $propertyFilter
                    Add-Member -InputObject $baseObject -MemberType NoteProperty -Name "skus" -Value $Skus 
                }
                else {
                    "No SKUs found for region $region"
                    $baseObject | Add-Member -MemberType NoteProperty -Name "skus" -Value @()
                }
                $outArray += $baseObject
            }
        }
        Add-Member -InputObject $resourceObject -MemberType NoteProperty -Name "Availability" -Value $outArray
        $Script:overAllObj += $resourceObject
        Out-JSONFile -Data $resourceObject -fileName $outPutFile
    }
    else {
        Write-Output "No property mapping found for resource type: $ResourceType"
    }
}

function Import-CurrentEnvironment {
    # Check if the summary file exists and load it
    if (Test-Path $SummaryFilePath) {
        Write-Output "  Loading summary file: $SummaryFilePath" | Out-Host
        $CurrentEnvironment = Get-Content -Path $SummaryFilePath -raw | ConvertFrom-Json -depth 10
    }
    else {
        Write-Output "File '$SummaryFilePath' not found."
        exit 1
    }
    # Check for empty SKUs and remove 'ResourceSkus' property if its value is 'N/A' in the current implementation data
    Write-Output "  Cleaning up implementation data" | Out-Host
    return @{
        Data = $CurrentEnvironment
    }
}

function Expand-CurrentToGlobal {
    # This function expands the currently implemented resources to show their availability across all Azure regions,
    # without considering specific SKUs. It adds the AllRegions property to each resource in the AvailabilityMapping.
    Write-Output "Working on general availability mapping without SKU consideration"
    Write-Output "  Adding Azure regions with resource availability information"
    $Resources_TotalImplementations = $AvailabilityMapping.Count
    $Resources_CurrentImplementationIndex = 0
    foreach ($resource in $AvailabilityMapping) {
        $Resources_CurrentImplementationIndex++
        Write-Output ("    Processing resource type {0:D03} of {1:D03}: {2}" -f $Resources_CurrentImplementationIndex, $Resources_TotalImplementations, $resource.ResourceType)
        # Split the resource type string into namespace and type (keeping everything after the first "/" as the type)
        $splitParts = $resource.ResourceType -split "/", 2
        $ns = $splitParts[0]
        $rt = $splitParts[1]
        # Find the namespace object in Resources_All
        $nsObject = $Resources_All | Where-Object { $_.Namespace -ieq $ns }
        # Locate the corresponding resource type under that namespace
        $resourceTypeObject = $nsObject.ResourceTypes | Where-Object { $_.Type -ieq $rt }
        $MappedRegions = @()
        foreach ($Region in $Regions_All.Regions.value) {
            # Check if the region is available for the resource type or if it's global available
            $availability = if ($resourceTypeObject.Locations -contains $Region.name -or $resourceTypeObject.Locations -contains "Global") { "true" } else { "false" }
            $MappedRegions += New-Object -TypeName PSObject -Property @{
                region    = $Region.name
                available = $availability
            }
        }
        # Add or replace the AllRegions property with the mapped availability array
        $resource | Add-Member -Force -MemberType NoteProperty -Name AllRegions -Value $MappedRegions
    }
}

function Initialize-SKU2Region {
    # This function initializes the mapping of SKUs to regions for resource types that have implemented SKUs,
    # ensuring that the SKUs are added to the regions where the resource type is available.
    Write-Output "Working on availability SKU mapping"
    Write-Output "  Adding implemented SKUs to Azure regions with general availability"
    foreach ($resource in $AvailabilityMapping) {
        if ($resource.ImplementedSkus -and ($resource.ImplementedSkus[0] -ne "N/A")) {
            "implemented skus found for resource type $($resource.ResourceType) is not N/A"
            foreach ($Region in $resource.AllRegions) {
                if ($Region.available -eq "true") {
                    #$Region.region
                    # Add the SKUs property containing the array from the current resource object.
                    $Region | Add-Member -MemberType NoteProperty -Name SKUs -Value $resource.ImplementedSkus -Force
                }
            }
        }
    }
}
function Update-SKUProperties {
    param (
        [Parameter(Mandatory)] [string]$RegionName,
        [Parameter(Mandatory)] [pscustomobject]$Object,
        [Parameter(Mandatory)] [string]$availabilityStatus,
        [Parameter(Mandatory)] [PSCustomObject]$sku
    )
    $region = $Object.AllRegions | Where-Object { $_.region -eq $RegionName }
    Write-Host "Updating SKUs in region '$RegionName'..."
    foreach ($targetSku in $region.SKUs) {
        if (Compare-ObjectsStrict -Object1 $sku -Object2 $targetSku) {
            Write-Host "Setting availability of '$($targetSku.Name)' to '$availabilityStatus' in region '$RegionName'"
            Add-Member -InputObject $targetSku -MemberType NoteProperty -Name "available" -Value $availabilityStatus -Force
        }
    }
}

#Main script starts here
clear-host
$starttime = Get-Date
$subscriptionId = (Get-AzContext).Subscription.Id
$uriRoot = "https://management.azure.com/subscriptions/$subscriptionId"
$script:overAllObj = @()
$Regions_All = Import-Region
$Resources_All = (Import-Provider -uriRoot $uriRoot).Data
# # Import current environment data from the summary file of script 1-Collect
$AvailabilityMapping = (Import-CurrentEnvironment).Data
# # Expand the current implementation to show availability across all Azure regions 
Expand-CurrentToGlobal
# # Initialize SKU to region mapping for resources that have implemented SKUs
Initialize-SKU2Region
$AvailabilityMapping = $AvailabilityMapping | ForEach-Object { $PSItem | ConvertTo-Json -depth 10 | convertfrom-json }
foreach ($resourceType in $AvailabilityMapping.ResourceType) {
    Get-ResourceType -ResourceType $resourceType
}
#Verify availability mapping for specific SKUs
Foreach ($cResource in $overAllObj) {
    $availScope = $availabilityMapping | Where-Object { $psitem.ResourceType -eq $cResource.ResourceType }
    $cResource.ResourceType
    Foreach ($sku in $availScope.ImplementedSkus) {
        Foreach ($region in $cResource.Availability) { 
            $regionCode = $region.RegionCode; 
            If ($region.skus.count -ne 0) {
                $skuFound = $region.skus | Where-Object { Compare-ObjectsStrict -Object1 ([PSCustomObject]$PSItem) -Object2 $sku -verbose }
                If ($skuFound -ne $null) { 
                    "SUCCESS: SKU $sku found in region $regionCode";
                    Update-SKUProperties -RegionName $regionCode -Object $availScope -availabilityStatus true -sku $sku
                } 
                else { 
                    "SKU $sku not found in region $regionCode"; 
                    Update-SKUProperties -RegionName $regionCode -Object $availScope -availabilityStatus false -sku $sku
                }
            }
            else {
                "No SKUs found for region $regionCode";
            }
        }    
    }
    $cResource.ResourceType
}
Out-JSONFile -Data $AvailabilityMapping -fileName "Availability_Mapping.json"
$endtime = Get-Date
$minutes = (New-TimeSpan -Start $starttime -End $endtime).TotalMinutes
Write-Output "Ending script $endtime after $minutes minutes"