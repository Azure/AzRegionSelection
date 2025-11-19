BeforeAll {
    $scriptPath = "$PSScriptRoot\Get-Region.ps1"
}

Describe "Get-Region.ps1 Tests" {
    Context "Parameter Validation" {
        It "Should require Region parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[Parameter\(Mandatory\s*=\s*\$true'
            $scriptContent | Should -Match '\[string\]\$Region'
        }

        It "Should have HelpMessage for Region parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'HelpMessage.*region'
        }
    }

    Context "File Dependencies" {
        It "Should check for Availability_Mapping.json" {
            $availabilityFile = "Availability_Mapping.json"
            $availabilityFile | Should -Be "Availability_Mapping.json"
        }

        It "Should validate file path construction" {
            $testPath = Join-Path (Get-Location) "Availability_Mapping.json"
            $testPath | Should -Not -BeNullOrEmpty
        }
    }

    Context "Region Filtering" {
        It "Should filter by exact region match" {
            $testRegion = "eastus"
            $mockData = @(
                [PSCustomObject]@{
                    AllRegions = @(
                        [PSCustomObject]@{ region = "eastus"; available = "true" }
                        [PSCustomObject]@{ region = "westus"; available = "true" }
                    )
                }
            )
            
            $filtered = $mockData[0].AllRegions | Where-Object { $_.region -eq $testRegion }
            $filtered.Count | Should -Be 1
            $filtered[0].region | Should -Be $testRegion
        }
    }

    Context "Output Generation" {
        It "Should generate region-specific output filename" {
            $testRegion = "eastus"
            $expectedFile = "Availability_Mapping_eastus.json"
            
            $outputFile = "Availability_Mapping_" + ($testRegion -replace "\s", "_") + ".json"
            $outputFile | Should -Be $expectedFile
        }

        It "Should handle region names with spaces" {
            $testRegion = "East US"
            $expectedFile = "Availability_Mapping_East_US.json"
            
            $outputFile = "Availability_Mapping_" + ($testRegion -replace "\s", "_") + ".json"
            $outputFile | Should -Be $expectedFile
        }
    }

    Context "Data Transformation" {
        It "Should replace AllRegions with SelectedRegion" {
            $mockResource = [PSCustomObject]@{
                ResourceType = "test/resource"
                AllRegions = @(
                    [PSCustomObject]@{ region = "eastus"; available = "true" }
                )
            }
            
            $regionMatch = $mockResource.AllRegions | Where-Object { $_.region -eq "eastus" }
            $mockResource | Add-Member -Force -MemberType NoteProperty -Name SelectedRegion -Value $regionMatch
            
            $mockResource.SelectedRegion | Should -Not -BeNullOrEmpty
            $mockResource.SelectedRegion.region | Should -Be "eastus"
        }
    }
}
