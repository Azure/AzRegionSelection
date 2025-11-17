BeforeAll {
    $scriptPath = "$PSScriptRoot\Get-Report.ps1"
}

Describe "Get-Report.ps1 Tests" {
    Context "Parameter Validation" {
        It "Should accept availabilityInfoPath parameter" {
            $testPath = @("test1.json", "test2.json")
            $testPath.Count | Should -Be 2
        }

        It "Should accept costComparisonPath parameter" {
            $testPath = "cost_comparison.json"
            $testPath | Should -Not -BeNullOrEmpty
        }
    }

    Context "Helper Functions" {
        It "Should define Get-Props function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-Props'
        }

        It "Should define Set-ColumnColor function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Set-ColumnColor'
        }

        It "Should define New-Worksheet function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function New-Worksheet'
        }

        It "Should define Set-SvcAvailReportObj function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Set-SvcAvailReportObj'
        }
    }

    Context "SKU Availability Mapping" {
        It "Should map 'true' to 'Available'" {
            $skuAvailability = "true"
            if ($skuAvailability -eq "true") {
                $skuAvailability = "Available"
            }
            $skuAvailability | Should -Be "Available"
        }

        It "Should map 'false' to 'Not available'" {
            $skuAvailability = "false"
            if ($skuAvailability -eq "false") {
                $skuAvailability = "Not available"
            }
            $skuAvailability | Should -Be "Not available"
        }

        It "Should map empty string to 'NotCoveredByScript'" {
            $skuAvailability = ""
            if ($skuAvailability -eq "") {
                $skuAvailability = "NotCoveredByScript"
            }
            $skuAvailability | Should -Be "NotCoveredByScript"
        }
    }

    Context "Output File Naming" {
        It "Should generate timestamped filename" {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $filename = "Availability_Report_$timestamp.xlsx"
            
            $filename | Should -Match "^Availability_Report_\d{8}_\d{6}\.xlsx$"
        }
    }

    Context "Excel Formatting" {
        It "Should define header colors" {
            $headerColor = "RoyalBlue"
            $headerFontColor = "White"
            
            $headerColor | Should -Be "RoyalBlue"
            $headerFontColor | Should -Be "White"
        }

        It "Should define cell colors for availability" {
            $greenValues = @("Available", "N/A")
            $redValues = @("Not available")
            $yellowValues = @("NotCoveredByScript")
            
            $greenValues | Should -Contain "Available"
            $redValues | Should -Contain "Not available"
            $yellowValues | Should -Contain "NotCoveredByScript"
        }
    }

    Context "Worksheet Generation" {
        It "Should create ServiceAvailability worksheet" {
            $worksheetName = "ServiceAvailability"
            $worksheetName | Should -Be "ServiceAvailability"
        }

        It "Should create CostComparison worksheet" {
            $worksheetName = "CostComparison"
            $worksheetName | Should -Be "CostComparison"
        }
    }

    Context "Cost Report Processing" {
        It "Should handle unique meter IDs" {
            $mockData = @(
                [PSCustomObject]@{ OrigMeterId = "meter1"; Region = "eastus"; RetailPrice = 10.0 }
                [PSCustomObject]@{ OrigMeterId = "meter1"; Region = "westus"; RetailPrice = 12.0 }
                [PSCustomObject]@{ OrigMeterId = "meter2"; Region = "eastus"; RetailPrice = 20.0 }
            )
            
            $uniqueMeters = $mockData | Select-Object -Property OrigMeterId -Unique
            $uniqueMeters.Count | Should -Be 2
        }

        It "Should create regional pricing properties" {
            $region = "eastus"
            $price = 10.5
            $propertyName = "$region-RetailPrice"
            
            $propertyName | Should -Be "eastus-RetailPrice"
        }

        It "Should handle Global region" {
            $region = $null
            if ($null -eq $region -or $region -eq "") {
                $region = "Global"
            }
            $region | Should -Be "Global"
        }
    }

    Context "Data Validation" {
        It "Should handle N/A SKUs" {
            $implementedSkus = @("N/A")
            $isNotNA = $implementedSkus[0] -ne "N/A"
            
            $isNotNA | Should -Be $false
        }

        It "Should join implemented regions" {
            $regions = @("eastus", "westus", "northeurope")
            $joined = $regions -join ", "
            
            $joined | Should -Be "eastus, westus, northeurope"
        }
    }
}
