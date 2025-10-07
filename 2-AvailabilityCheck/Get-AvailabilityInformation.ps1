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

.OUTPUTS
    Azure_Providers.json
    All Azure providers and their resource types, including locations.

.OUTPUTS
    Azure_Regions.json
    All Azure regions with their display names, metadata, and availability information.

.OUTPUTS
    Azure_SKUs_SQL_Managed_Instance.json
    All Azure SQL managed instance SKUs with name and sku information.

.OUTPUTS
    Azure_SKUs_SQL_Server_Database.json
    All Azure SQL Server database SKUs with name, tier, family, and capacity information.

.OUTPUTS
    Azure_SKUs_StorageAccount.json
    All Azure storage account SKUs with their locations, tiers, and capabilities.

.OUTPUTS
    Azure_SKUs_VM.json
    All Azure VM SKUs with their locations, number of cores, and memory.

.NOTES
    - Requires Azure PowerShell module to be installed and authenticated.
#>

function Out-JSONFile {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Data,
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )
    # This function writes the provided data to a JSON file at the specified path.
    Write-Output "  Writing data to file: $FileName" | Out-Host
    $Data | ConvertTo-Json -Depth 20 | Out-File -FilePath "$(Get-Location)\$FileName" -Force
}

function Write-Headline {
    param (
    [Parameter(Mandatory = $true)]
    [object]$Text
    )
    Write-Output "####################################################################################################"
    Write-Output "   $Text"
    Write-Output "####################################################################################################"
    Write-Output ""
}
function Initialize-RESTAPI {
    # This function retrieves the access token and subscription ID, and sets up the URI and headers for REST API calls.
    Write-Output "Initializing REST API" | Out-Host
    Write-Output "  Retrieving access token and subscription ID" | Out-Host
    # Retrieve the access token as a secure string and convert it to a regular string
    $SecureAccessToken = Get-AzAccessToken -AsSecureString
    $AccessToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureAccessToken.Token))
    # Retrieve the subscription ID from the current Azure context
    $SubscriptionId = (Get-AzContext).Subscription.Id
    Write-Output "    Access token and Subscription ID successfully retrieved" | Out-Host
    Write-Output "    Subscription ID: $SubscriptionId" | Out-Host
    Write-Output "  Setting up BaseUri and headers" | Out-Host
    # Set up the headers for the REST API calls
    $Headers = @{
        Authorization = "Bearer $AccessToken"
    }
    return @{
        Headers = $Headers
        Uri = "https://management.azure.com/subscriptions/$SubscriptionId"
    }
}

function Import-Provider {
    # This function retrieves all available Azure providers and their resource types, including locations.
    Write-Output "Retrieving all available provider" | Out-Host
    $Response = Invoke-RestMethod -Uri "$($RESTAPI.Uri)/providers?api-version=2021-04-01" -Headers $RESTAPI.Headers -Method Get
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
    # Save providers to a JSON file
    Out-JSONFile -Data $Providers -fileName "Azure_Providers.json"
    return @{
        Data = $Providers
    }
}

function Import-Region {
    # This function retrieves all Azure regions, sorts them alphabetically, flattens metadata to the top level, and removes PII information.
    Write-Output "Working on regions" | Out-Host
    Write-Output "  Retrieving regions information" | Out-Host
    $Response = Invoke-RestMethod -Uri "$($RESTAPI.Uri)/locations?api-version=2022-12-01" -Headers $RESTAPI.Headers -Method Get
    # Sort regions alphabetically by displayName
    Write-Output "  Sorting regions" | Out-Host
    $Response.value = $Response.value | Sort-Object displayName
    # Flatten metadata to the top level and remove PII information
    Write-Output "  Region information flattening and PII deletion" | Out-Host
    $ConsolidatedRegions = @()
    $TotalRegions = $Response.value.Count
    $CurrentRegionIndex = 0
    foreach ($Region in $Response.value) {
        $CurrentRegionIndex++
        Write-Output ("    Removing information for region {0:D03} of {1:D03}: {2}" -f $CurrentRegionIndex, $TotalRegions, $Region.displayName) | Out-Host
        if ($Region.metadata) {
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
    foreach ($Location in $Response.value) {
        $RegionMap[$Location.name] = $Location.displayName
    }

    # Save regions to a JSON file
    Out-JSONFile -Data $Response -fileName "Azure_Regions.json"
    return @{
        Regions = $Response
        Map     = $RegionMap
    }
}

function Import-SKU-VM {
    # This function retrieves all available VM SKUs across Azure regions and consolidates them.
    Write-Output "Working on VM SKUs" | Out-Host
    Write-Output "  Retrieving VM SKU regions information" | Out-Host
    $Response = Invoke-RestMethod -Uri "$($RESTAPI.Uri)/providers/Microsoft.Compute?api-version=2025-03-01" -Headers $RESTAPI.Headers -Method Get
    # Filter for the resource type "virtualMachines" and extract its locations array
    $Regions = ($Response.resourceTypes | Where-Object { $_.resourceType -eq "virtualMachines" }).locations | Sort-Object
    # Retrieve SKU information for every region where VM SKUs are available
    Write-Output "  Adding VM SKUs for consolidated regions" | Out-Host
    $ConsolidatedSKUs = @{}
    $TotalRegions = $Regions.Count
    $CurrentRegionIndex = 0
    foreach ($Region in $Regions) {
        $CurrentRegionIndex++
        Write-Output ("    Retrieving VM SKUs for region {0:D03} of {1:D03}: {2}" -f $CurrentRegionIndex, $TotalRegions, $Region) | Out-Host
        # REST API endpoint for VM SKUs
        $Response2 = Invoke-RestMethod -Uri "$($RESTAPI.Uri)/providers/Microsoft.Compute/locations/$Region/vmSizes?api-version=2024-07-01" -Headers $RESTAPI.Headers -Method Get
        # Process the API response
        foreach ($size in $Response2.value) {
            if (-not $ConsolidatedSKUs.ContainsKey($size.name)) {
                $ConsolidatedSKUs[$size.name] = @{
                    Name          = $size.name
                    Locations     = @($Region)  # Initialize with the current region
                    NumberOfCores = $size.numberOfCores
                    MemoryInMB    = $size.memoryInMB
                }
            } else {
                # Add the region to the existing size's locations, ensuring no duplicates
                if (-not ($ConsolidatedSKUs[$size.name].Locations -contains $Region)) {
                    $ConsolidatedSKUs[$size.name].Locations += $Region
                }
            }
        }
    }
    # Convert the hash table to an array and save the VM SKUs to a JSON file
    $SKUs = $ConsolidatedSKUs.Values
    # Save VM SKUs to a JSON file
    Out-JSONFile -Data $SKUs -fileName "Azure_SKUs_VM.json"
    return @{
    Data = $SKUs
    }
}

function Import-SKU-SQL {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ResourceTypeSQL
    )
    # This function retrieves the SKU information for SQL resources based on the specified resource type.
    switch ($ResourceTypeSQL) {
        "servers/databases" {
           $OutputText = "SQL Server database"
           $OutputFile = "Azure_SKUs_SQL_Server_Database.json"
        }
        "managedInstances" {
            $OutputText = "SQL managed instance"
            $OutputFile = "Azure_SKUs_SQL_Managed_Instance.json"
        }
        default {
            Write-Output "    No SKUs found for this resource type." | Out-Host
            return
        }
    }
    Write-Output "Working on $OutputText SKUs" | Out-Host
    $SKUs = @()
    # Find the Microsoft.Sql provider from the available providers
    Write-Output "  Retrieving $OutputText SKU regions information" | Out-Host
    $Resources_SQL = $Resources_All | Where-Object { $_.Namespace -ieq "Microsoft.Sql" }
    if ($Resources_SQL) {
        # Select the resource type for specific SQL SKUs
        $Resource_SQL = $Resources_SQL.ResourceTypes | Where-Object { $_.Type -ieq $ResourceTypeSQL }
        if ($Resource_SQL) {
            Write-Output "  Adding $OutputText SKUs for consolidated regions" | Out-Host
            $Regions = $Resource_SQL.Locations
            $TotalRegions = $Regions.Count
            $CurrentRegionIndex = 0
            foreach ($Region in $Regions) {
                $CurrentRegionIndex++
                # Convert the display region into a region code for the URL
                $RegionCode = ($Region -replace '\s','').ToLower()
                Write-Output ("    Retrieving $OutputText SKU for region {0:D03} of {1:D03}: {2}" -f $CurrentRegionIndex, $TotalRegions, $Region) | Out-Host
                try {
                    switch ($ResourceTypeSQL) {
                        "servers/databases" {
                            # Process SKUs SQL servers databases
                            $Response = Invoke-RestMethod -Uri "$($RESTAPI.Uri)/providers/Microsoft.Sql/locations/$RegionCode/capabilities?api-version=2021-02-01-preview" -Headers $RESTAPI.Headers -Method Get
                            # Select only the supportedServerVersions property from the response
                            $FilteredCapabilities = $Response | Select-Object -Property supportedServerVersions
                            # Rebuild supportedServerVersions
                            if ($FilteredCapabilities -and $FilteredCapabilities.supportedServerVersions) {
                                $FilteredCapabilities.supportedServerVersions = $FilteredCapabilities.supportedServerVersions | ForEach-Object {
                                    $allSkus = @()
                                    if ($_.supportedEditions) {
                                        foreach ($edition in $_.supportedEditions) {
                                            if ($edition.supportedServiceLevelObjectives) {
                                                $allSkus += ($edition.supportedServiceLevelObjectives | ForEach-Object {
                                                    $_.sku
                                                })
                                            }
                                        }
                                    }
                                    # Group and consolidate duplicates based on sku name, tier, family, and capacity
                                    $uniqueSkus = $allSkus |
                                        Group-Object -Property { "$($_.name)|$($_.tier)|$($_.family)|$($_.capacity)" } |
                                        ForEach-Object { $_.Group[0] }
                                    # Transform each consolidated SKU object, retaining the original properties
                                    $uniqueSkus = $uniqueSkus | ForEach-Object {
                                        $obj = [PSCustomObject]@{
                                            name     = $_.name
                                            tier     = $_.tier
                                            capacity = $_.capacity
                                        }
                                        if ($_.family) {
                                            $obj | Add-Member -MemberType NoteProperty -Name family -Value $_.family
                                        }
                                        $obj
                                    }
                                    [PSCustomObject]@{
                                        skus = $uniqueSkus
                                    }
                                }
                            }
                            # Flatten the output
                            if ($FilteredCapabilities.supportedServerVersions.Count -gt 0) {
                                $sv = $FilteredCapabilities.supportedServerVersions[0]
                            }
                            else {
                                $sv = [PSCustomObject]@{ skus = @() }
                            }
                            # Append the flattened object with region context
                            $SKUs += [PSCustomObject]@{
                                Region     = $Region
                                RegionCode = $RegionCode
                                skus       = $sv.skus
                            }
                        }
                        "managedInstances" {
                            # Process SKUs for SQL managed instances
                            $Response = Invoke-RestMethod -Uri "$($RESTAPI.Uri)/providers/Microsoft.Sql/locations/$RegionCode/capabilities?api-version=2021-02-01-preview" -Headers $RESTAPI.Headers -Method Get
                            # Select only the supportedManagedInstanceVersions property from the response
                            $FilteredCapabilities = $Response | Select-Object -Property supportedManagedInstanceVersions
                            # Rebuild supportedManagedInstanceVersions
                            if ($FilteredCapabilities -and $FilteredCapabilities.supportedManagedInstanceVersions) {
                                $FilteredCapabilities.supportedManagedInstanceVersions = $FilteredCapabilities.supportedManagedInstanceVersions | ForEach-Object {
                                    $allSkus = @()
                                    if ($_.supportedEditions) {
                                        foreach ($edition in $_.supportedEditions) {
                                            if ($edition.supportedFamilies) {
                                                foreach ($family in $edition.supportedFamilies) {
                                                    $allSkus += [PSCustomObject]@{
                                                        tier   = $edition.name
                                                        family = $family.name
                                                        name   = $family.sku
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    # Group and consolidate duplicates based on family and SKU
                                    $uniqueSkus = $allSkus | Group-Object -Property { "$($_.family)|$($_.name)" } | ForEach-Object { $_.Group[0] }
                                    [PSCustomObject]@{
                                        skus = $uniqueSkus
                                    }
                                }
                            }
                            # Flatten the output
                            if ($FilteredCapabilities.supportedManagedInstanceVersions.Count -gt 0) {
                                $sv = $FilteredCapabilities.supportedManagedInstanceVersions[0]
                            }
                            else {
                                $sv = [PSCustomObject]@{ skus = @() }
                            }
                            # Append the flattened object with region context
                            $SKUs += [PSCustomObject]@{
                                Region     = $Region
                                RegionCode = $RegionCode
                                skus       = $sv.skus
                            }
                        }
                    }
                }
                catch {
                    Write-Output ("      Error retrieving $OutputText SKUs for {0}: {1}" -f $RegionCode, $_.Exception.Message) | Out-Host
                }
            }
        }
        else {
            Write-Output "  No resource type '$ResourceTypeSQL' found for Microsoft.Sql in provider information." | Out-Host
        }
    }
    else {
        Write-Output "  Microsoft.Sql provider not found in provider information." | Out-Host
    }
    # Save SQL SKUs to a JSON file
    Out-JSONFile -Data $SKUs -fileName $OutputFile
    return @{
        Data = $SKUs
    }
}

function Import-SKU-StorageAccount {
    # This function retrieves all available storage account SKUs across Azure regions and consolidates them.
    Write-Output "Working on storage account SKUs" | Out-Host
    Write-Output "  Retrieving storage account SKUs" | Out-Host
    $SKUs = @()
    # REST API Endpoint for storage account SKUs
    $Response = Invoke-RestMethod -Uri "$($RESTAPI.Uri)/providers/Microsoft.Storage/skus?api-version=2021-01-01" -Headers $RESTAPI.Headers -Method Get
    # Sort storage account response by the first location value
    Write-Output "  Sorting storage account SKUs by location" | Out-Host
    $Response = $Response.value | Sort-Object { $_.locations[0] }
    # Replace region names with display names in $Response and property of regions not available in this subscription will be empty
    Write-Output "  Changing region names to display names" | Out-Host
    foreach ($obj in $Response) {
        $StorageAccount_NewLocations = @()
        foreach ($Region in $obj.locations) {
            if ($Regions_All.Map.ContainsKey($Region)) {
                $StorageAccount_NewLocations += $Regions_All.Map[$Region]
            }
        }
        $obj.locations = $StorageAccount_NewLocations
    }
    # Filter out SKU objects whose locations array is empty
    Write-Output "  Removing regions not available in this subscription" | Out-Host
    $Response = $Response | Where-Object { $_.locations.Count -gt 0 }
    # Count distinct storage account locations, excluding empty strings
    Write-Output "  Adding storage account SKUs for consolidated regions" | Out-Host
    $LastRegion = $null
    $TotalRegions = ($Response | ForEach-Object { $_.locations[0] } | Where-Object { $_ -ne "" } | Sort-Object | Get-Unique).Count
    $CurrentRegionIndex = 0
    $Response | ForEach-Object {
        $Region = $_.locations[0]
        if ($Region -ne $LastRegion) {
            $CurrentRegionIndex++
            $LastRegion = $Region
            Write-Output ("    Retrieving storage account SKUs for region {0:D03} of {1:D03}: {2}" -f $CurrentRegionIndex, $TotalRegions, $Region) | Out-Host
        }
        # Convert Capabilities into individual properties
        $CapabilitiesProperties = @{}
        $_.capabilities | ForEach-Object {
            $Capability = "$($_.name):$($_.value)"
            $NameValuePair = $Capability -split ":"
            if ($NameValuePair.Length -eq 2) {
                $Key = $NameValuePair[0].Trim()
                $CapabilitiesProperties[$Key] = $NameValuePair[1].Trim()
            }
        }
        foreach ($Location in $_.locations) {  # Process each location as its own entry
            $SKUs += @{
                Name     = $_.name
                Location = $Location
                Tier     = $_.tier
                Kind     = $_.kind
            }
            # Flatten the details properties to top-level
            foreach ($key in $CapabilitiesProperties.Keys) {
                $SKUs[-1] | Add-Member -MemberType NoteProperty -Name $key -Value $CapabilitiesProperties[$key] -Force
            }
        }
    }
    # Save the storage account SKUs to a JSON file
    Out-JSONFile -Data $SKUs -fileName "Azure_SKUs_StorageAccount.json"
    return @{
        Data = $SKUs
    }
}

function Import-CurrentEnvironment {
    # This function imports the current implementation data from the summary file of script 1-Collect,
    # processes it to remove empty SKUs, and renames properties for clarity.
    Write-Output "Retrieving current implementation information" | Out-Host
    $SummaryFilePath = "$(Get-Location)\..\1-Collect\summary.json"
    # Check if the summary file exists and load it
    if (Test-Path $SummaryFilePath) {
        Write-Output "  Loading summary file: ../1-Collect/summary.json" | Out-Host
        $CurrentEnvironment = Get-Content -Path $SummaryFilePath | ConvertFrom-Json
    } else {
        Write-Output "File 'summary.json' not found in '../1-Collect/summary.json'."
        exit 1
    }
    # Check for empty SKUs and remove 'ResourceSkus' property if its value is 'N/A' in the current implementation data
    Write-Output "  Cleaning up implementation data" | Out-Host
    $CurrentEnvironment = $CurrentEnvironment | ForEach-Object {
        if (((($_.ResourceSkus -is [array]) -and ($_.ResourceSkus.Count -eq 1) -and ($_.ResourceSkus[0] -eq "N/A"))) -or ($_.ResourceSkus -eq "N/A")) {
            $_ | Select-Object * -ExcludeProperty ResourceSkus
        }
        else {
            $_
        }
    }
    # Change of property names to better distinguish between current implementation and Azure availability data
    Write-Output "  Massaging implementation data" | Out-Host
    $CurrentEnvironment = $CurrentEnvironment | ForEach-Object {
        $obj = $_
        # Rename 'AzureRegions' to 'ImplementedRegions'
        if ($obj.PSObject.Properties["AzureRegions"]) {
            $newRegions = @()
            foreach ($Region in $obj.AzureRegions) {
                if ($Regions_All.Map.ContainsKey($Region)) {
                    $newRegions += $Regions_All.Map[$Region]
                }
                else {
                    $newRegions += $Region
                }
            }
            $obj | Add-Member -Force -MemberType NoteProperty -Name ImplementedRegions -Value $newRegions
            $obj = $obj | Select-Object * -ExcludeProperty AzureRegions
        }
        # Rename 'ResourceSkus' to 'ImplementedSkus'
        if ($obj.PSObject.Properties["ResourceSkus"]) {
            $newSkus = @()
            foreach ($sku in $obj.ResourceSkus) {
                $newSkus += $sku
            }
            $obj | Add-Member -Force -MemberType NoteProperty -Name ImplementedSkus -Value $newSkus
            $obj = $obj | Select-Object * -ExcludeProperty ResourceSkus
        }
        $obj
    }
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
        if ($splitParts.Length -eq 2) {
            $ns = $splitParts[0]
            $rt = $splitParts[1]
            # Find the namespace object in Resources_All
            $nsObject = $Resources_All | Where-Object { $_.Namespace -ieq $ns }
            if ($nsObject) {
                # Locate the corresponding resource type under that namespace
                $resourceTypeObject = $nsObject.ResourceTypes | Where-Object { $_.Type -ieq $rt }
                if ($resourceTypeObject) {
                    # Create a regions array and exclude "Global" regions
                    $MappedRegions = @()
                    foreach ($Region in $Regions_All.Regions.value) {
                        # Skip adding the region if its displayName is "Global"
                        if ($Region.displayName -eq "Global") { continue }
                        # Check if the region is available for the resource type or if it's global available
                        $availability = if ($resourceTypeObject.Locations -contains $Region.displayName -or $resourceTypeObject.Locations -contains "Global") { "true" } else { "false" }
                        $MappedRegions += New-Object -TypeName PSObject -Property @{
                            region    = $Region.displayName
                            available = $availability
                        }
                    }
                    # Add or replace the AllRegions property with the mapped availability array
                    $resource | Add-Member -Force -MemberType NoteProperty -Name AllRegions -Value $MappedRegions
                } else {
                    Write-Output ("      Resource type '{0}' under namespace '{1}' not found in Resources_All" -f $rt, $ns)
                }
            } else {
                Write-Output ("      Namespace '{0}' not found in Resources_All" -f $ns)
            }
        } else {
            Write-Output ("      Invalid ResourceType format: {0}" -f $resource.ResourceType)
        }
    }
}
function Initialize-SKU2Region {
    # This function initializes the mapping of SKUs to regions for resource types that have implemented SKUs,
    # ensuring that the SKUs are added to the regions where the resource type is available.
    Write-Output "Working on availability SKU mapping"
    Write-Output "  Adding implemented SKUs to Azure regions with general availability"
    foreach ($resource in $AvailabilityMapping) {
        if ($resource.ImplementedSkus) {
            foreach ($Region in $resource.AllRegions) {
                if ($Region.available -eq "true") {
                    # Add the SKUs property containing the array from the current resource object.
                    $Region | Add-Member -MemberType NoteProperty -Name SKUs -Value $resource.ImplementedSkus -Force
                }
            }
        }
    }
}

function Join-SKU2Region {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ResourceType
    )
    # This function processes the SKUs for a given resource type and joins them with the regions where they are available.
    Write-Output "  Processing SKUs for resource type: $ResourceType"
    foreach ($resource in $AvailabilityMapping) {
        if ($resource.ResourceType -ieq $ResourceType) {
            # Filter regions to those available and having a SKUs property
            $Location_ValidRegions = $resource.AllRegions | Where-Object { $_.available -eq "true" -and $_.SKUs }
            $TotalRegions = $Location_ValidRegions.Count
            $CurrentRegionIndex = 0
            foreach ($Region in $Location_ValidRegions) {
                $CurrentRegionIndex++
                Write-Output ("    Processing region {0:D3} of {1:D3}: {2}" -f $CurrentRegionIndex, $TotalRegions, $Region.region)
                $newSKUs = @()
                switch ($ResourceType) {
                    {($_ -eq "microsoft.compute/disks") -or ($_ -eq "microsoft.storage/storageaccounts")} {
                        # Process SKUs for compute disks or storage accounts
                        # # Check for compute disks is against storage account SKUs because because compute disks will be reported back in storage account SKU format
                        foreach ($sku in $Region.SKUs) {
                            $isAvailable = "false"
                            foreach ($store in $StorageAccount_SKU) {
                                # Check if the SKU locations information contains the region and a matching SKU
                                if (($store.Location -ieq $Region.region) -and ($store.Name -eq $sku.name) -and ($store.Tier -eq $sku.tier)) {
                                    $isAvailable = "true"
                                    break  # Found a matching SKU; stop looping
                                }
                            }
                            # Create a new object for the SKU
                            $newObj = New-Object PSObject -Property @{
                                name      = $sku.name
                                tier      = $sku.tier
                                available = $isAvailable
                            }
                            $newSKUs += $newObj
                        }
                    }
                    "microsoft.compute/virtualMachines" {
                        # Process SKUs for virtual machines
                        foreach ($sku in $Region.SKUs) {
                            # Convert SKU to string and extract the value using a regex
                            $skuStr = [string]$sku
                            if ($skuStr -match 'vmSize=(.+?)}') {
                                $skuName = $matches[1]
                            }
                            $isAvailable = "false"
                            foreach ($vmSku in $VM_SKU) {
                                # Check if the SKU locations information contains the region and a matching SKU
                                if (($vmSku.Locations -contains $Region.region) -and ($vmSku.Name -eq $skuName)) {
                                    $isAvailable = "true"
                                    break  # Found a matching SKU; stop looping
                                }
                            }
                            # Create a new object for the SKU
                            $newObj = New-Object PSObject -Property @{
                                name      = $skuName
                                available = $isAvailable
                            }
                            $newSKUs += $newObj
                        }
                    }
                    "microsoft.sql/managedinstances" {
                        # Process SKUs for SQL managed instances.
                        $implSku = $resource.ImplementedSkus
                        if ($implSku -and -not ($implSku -is [array])) {
                            $implSku = @($implSku)
                        }
                        # Retrieve SQL managed instance SKU availability for the current region.
                        $sqlRegionData = $SQL_ManagedInstance_SKU | Where-Object {
                            ($_.Region -ieq $Region.region) -or ($_.RegionCode -ieq $Region.region)
                        }
                        foreach ($sku in $implSku) {
                            $isAvailable = "false"
                            if ($sqlRegionData) {
                                foreach ($dbSku in $sqlRegionData.skus) {
                                    $matchName   = ($dbSku.name -ieq $sku.name)
                                    $matchTier   = ($dbSku.tier -ieq $sku.tier)
                                    $matchFamily = ($dbSku.family -ieq $sku.family)
                                    # Capacity property can be ignored for managed instances because if all other properties match, it can be considered available.
                                    if ($matchName -and $matchTier -and $matchFamily) {
                                        $isAvailable = "true"
                                        break  # Found a matching SKU; stop looping.
                                    }
                                }
                            }
                            # Create a new object for the SKU.
                            $newObj = New-Object PSObject -Property @{
                                name      = $sku.name
                                tier      = $sku.tier
                                family    = $sku.family
                                available = $isAvailable
                            }
                            $newSKUs += $newObj
                        }
                    }
                    "microsoft.sql/servers/databases" {
                        # Process SKUs for SQL Server databases
                        $sqlRegionData = $SQL_Server_Database_SKU | Where-Object { $_.Region -ieq $Region.region }
                        foreach ($sku in $Region.SKUs) {
                            $isAvailable = "false"
                            if ($sqlRegionData) {
                                foreach ($dbSku in $sqlRegionData.skus) {
                                    $matchName     = ($dbSku.name -eq $sku.name)
                                    $matchTier     = ($dbSku.tier -eq $sku.tier)
                                    $matchCapacity = ($dbSku.capacity -eq $sku.capacity)
                                    # Check for family property if it exists on either side.
                                    $matchFamily = $true
                                    if ($sku.PSObject.Properties["family"] -or $dbSku.PSObject.Properties["family"]) {
                                        $matchFamily = ($dbSku.family -eq $sku.family)
                                    }
                                    if ($matchName -and $matchTier -and $matchCapacity -and $matchFamily) {
                                        $isAvailable = "true"
                                        break  # Found a matching SKU; stop looping.
                                    }
                                }
                            }
                            # Create a new object for the SKU.
                            $newObjProps = @{
                                name      = $sku.name
                                tier      = $sku.tier
                                capacity  = $sku.capacity
                                available = $isAvailable
                            }
                            # Family is not always present, so check if it exists before adding
                            if ($sku.PSObject.Properties["family"]) {
                                $newObjProps.Add("family", $sku.family)
                            }
                            $newObj = New-Object PSObject -Property $newObjProps
                            $newSKUs += $newObj
                        }
                    }
                    default {
                        Write-Output "    No SKUs found for this resource type."
                    }
                }
                # Replace the original SKUs array with the updated one
                $Region.SKUs = $newSKUs
            }
        }
    }
}

# Main script starts here
clear-host
# Start of resource and SKU availability retrieval
Write-Headline "RETRIEVING ALL AVAILABILITIES IN THIS SUBSCRIPTION"
# Initialize the REST API connection
$RESTAPI = Initialize-RESTAPI
# Import all resource types
$Resources_All = (Import-Provider).Data
# Import all Azure regions
$Regions_All = Import-Region
# Import VM SKUs
$VM_SKU = (Import-SKU-VM).Data
# Import SQL managed instance SKUs
$SQL_ManagedInstance_SKU = (Import-SKU-SQL -ResourceTypeSQL "managedInstances").Data
# Import SQL Server database SKUs
$SQL_Server_Database_SKU = (Import-SKU-SQL -ResourceTypeSQL "servers/databases").Data
# Import storage account SKUs
$StorageAccount_SKU = (Import-SKU-StorageAccount).Data
# Start of availability mapping to current implementation
Write-Headline "AVAILABILITY MAPPING TO CURRENT IMPLEMENTATION"
# Import current environment data from the summary file of script 1-Collect
$AvailabilityMapping = (Import-CurrentEnvironment).Data
# Expand the current implementation to show availability across all Azure regions
Expand-CurrentToGlobal
# Initialize SKU to region mapping for resources that have implemented SKUs
Initialize-SKU2Region
# Availability SKU mappings
Join-SKU2Region -ResourceType "microsoft.compute/disks"
Join-SKU2Region -ResourceType "microsoft.compute/virtualMachines"
Join-SKU2Region -ResourceType "microsoft.sql/managedinstances"
Join-SKU2Region -ResourceType "microsoft.sql/servers/databases"
Join-SKU2Region -ResourceType "microsoft.storage/storageaccounts"
# Save the availability mapping to a JSON file
Out-JSONFile -Data $AvailabilityMapping -fileName "Availability_Mapping.json"