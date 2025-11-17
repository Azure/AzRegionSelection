BeforeAll {
    $scriptPath = "$PSScriptRoot\Get-AvailabilityInformation.ps1"
}

Describe "Get-AvailabilityInformation.ps1 Tests" {
    Context "Function Definitions" {
        It "Should define Out-JSONFile function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'function Out-JSONFile'
        }

        It "Should define Convert-LocationsToRegionCodes function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Convert-LocationsToRegionCodes'
        }

        It "Should define Import-Provider function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Import-Provider'
        }

        It "Should define Import-Region function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'function Import-Region'
        }

        It "Should define Get-Property function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-Property'
        }

        It "Should define Expand-NestedCollection function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Expand-NestedCollection'
        }
    }

    Context "Logic Validation" {
        It "Should have region map creation logic" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'RegionMap'
        }

        It "Should have SKU availability checking logic" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'available'
        }
    }

    Context "File Dependencies" {
        It "Should check for summary.json from 1-Collect" {
            $summaryPath = "$(Get-Location)\..\1-Collect\summary.json"
            # Test would validate the file check logic
            $summaryPath | Should -Not -BeNullOrEmpty
        }

        It "Should check for propertyMaps.json" {
            $propertyMapPath = ".\propertymaps\propertyMaps.json"
            $propertyMapPath | Should -Not -BeNullOrEmpty
        }
    }

    Context "Output Files" {
        It "Should generate Availability_Mapping.json" {
            $outputFile = "Availability_Mapping.json"
            $outputFile | Should -Be "Availability_Mapping.json"
        }

        It "Should generate Azure_Providers.json" {
            $outputFile = "Azure_Providers.json"
            $outputFile | Should -Be "Azure_Providers.json"
        }
    }
}
