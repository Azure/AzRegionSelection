<#.SYNOPSIS
    Script to filter Get-Availability.ps1 results based on a specified region.

.DESCRIPTION
    This script filters the results of the Get-Availability.ps1 script based on a specified region.
    It loads the availability mapping from a JSON file, filters the entries to include only those
    that match the specified region, and saves the filtered results to a new JSON file.

.PARAMETER Region
    Specifies the region to run the query against. Regions should be provided as display names.

.EXAMPLE
    PS C:\> .\Get-Region.ps1 -Region 'Asia Pacific'
    Runs the script for a single subscription with the specified subscription ID and outputs the results
    to a file named 'Availability_Mapping_Asia_Pacific.json'.

.OUTPUTS
    JSON file containing availabilities from Availability_Mapping.json filtered by the specified region.

.NOTES
    - Requires Azure PowerShell module to be installed and authenticated.
#>

param(
    [Parameter(Mandatory = $true,
               HelpMessage = "Provide the region name as display name like in the Availability_Mapping.json file (e.g., 'Asia Pacific')")]
    [string]$Region
)

# Main script
clear-host
Write-Output "####################################################################################################"
Write-Output "## MAPPING AVAILABILITIES TO A SPECIFIC REGION                                                    ##"
Write-Output "####################################################################################################"
Write-Output ""

# Loading all region availabilities from the JSON file
Write-Output "Retrieving availability implementation for all regions"
$AvailabilityFilePath = Join-Path (Get-Location) "Availability_Mapping.json"
if (Test-Path $AvailabilityFilePath) {
    Write-Output "  Loading availability file: Availability_Mapping.json"
    $mappingData = Get-Content -Path $AvailabilityFilePath -Raw | ConvertFrom-Json
} else {
    Write-Output "File 'Availability_Mapping.json' was not found in the current directory."
    exit 1
}

# Filtering the JSON data to include only the specified region
Write-Output "Filtering availability implementation to a specific region"
Write-Output "  Selected region: $Region"
# Loop through every resource object in the JSON
$filteredResults = @()
foreach ($resource in $mappingData) {
    # Check if the resource object has an 'AllRegions' property
    if ($resource.PSObject.Properties.Name -contains "AllRegions" -and $resource.AllRegions) {
        # Filter the AllRegions array for entries that exactly match the specified region
        $regionMatches = $resource.AllRegions | Where-Object { $_.region -eq $Region }
        if ($regionMatches) {
            # Clone the resource object (so that only the matching regions are returned)
            $newResource = $resource | Select-Object *
            # Add a new property called 'SelectedRegion' with the matching regions
            $newResource | Add-Member -Force -MemberType NoteProperty -Name SelectedRegion -Value $regionMatches
            # Remove the original 'AllRegions' property.
            if ($newResource.PSObject.Properties.Name -contains "AllRegions") {
                $newResource.PSObject.Properties.Remove("AllRegions")
            }
            $filteredResults += $newResource
        }
    }
}

# Save the filtered information to a JSON file
if ($filteredResults.Count -eq 0) {
    Write-Output "No entries found for region: '$Region'"
} else {
    $outputFile = "Availability_Mapping_" + ($Region -replace "\s", "_") + ".json"
    $filteredResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding utf8
    Write-Output "  Filtered data saved to: $outputFile"
}
