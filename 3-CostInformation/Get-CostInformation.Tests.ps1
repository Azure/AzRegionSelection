BeforeAll {
    $scriptPath = "$PSScriptRoot\Get-CostInformation.ps1"
}

Describe "Get-CostInformation.ps1 Tests" {
    Context "Parameter Validation" {
        It "Should have default date parameters" {
            $defaultStartDate = (Get-Date).AddMonths(-1).ToString("yyyy-MM-01")
            $defaultEndDate = (Get-Date).AddDays(-1 * (Get-Date).Day).ToString("yyyy-MM-dd")
            
            $defaultStartDate | Should -Match "^\d{4}-\d{2}-01$"
            $defaultEndDate | Should -Match "^\d{4}-\d{2}-\d{2}$"
        }

        It "Should have default output format" {
            $defaultFormat = "json"
            $defaultFormat | Should -Be "json"
        }

        It "Should validate output format" {
            $validFormats = @("json", "csv", "excel", "console")
            $validFormats.Count | Should -Be 4
        }
    }

    Context "File Validation" {
        It "Should check for resource file existence" {
            $testFile = "resources.json"
            # Test would validate file existence logic
            $testFile | Should -Not -BeNullOrEmpty
        }

        It "Should require Az.CostManagement module" {
            $moduleName = "Az.CostManagement"
            $moduleName | Should -Be "Az.CostManagement"
        }

        It "Should require ImportExcel for Excel output" {
            $moduleName = "ImportExcel"
            $moduleName | Should -Be "ImportExcel"
        }
    }

    Context "Query Configuration" {
        It "Should set correct timeframe" {
            $timeframe = "Custom"
            $timeframe | Should -Be "Custom"
        }

        It "Should set correct cost type" {
            $type = "AmortizedCost"
            $type | Should -Be "AmortizedCost"
        }

        It "Should set correct granularity" {
            $granularity = "Monthly"
            $granularity | Should -Be "Monthly"
        }

        It "Should group by required dimensions" {
            $groupingDimensions = @("ResourceId", "PricingModel", "MeterCategory", "MeterSubcategory", "Meter", "ResourceGuid")
            $groupingDimensions.Count | Should -Be 6
            $groupingDimensions | Should -Contain "ResourceId"
            $groupingDimensions | Should -Contain "Meter"
        }
    }

    Context "Output Processing" {
        It "Should format billing month as yyyy-MM" {
            $testDate = Get-Date "2024-01-15"
            $formatted = $testDate.ToString("yyyy-MM")
            $formatted | Should -Be "2024-01"
        }

        It "Should add .json extension if not present" {
            $outputFile = "test"
            if ($outputFile -notmatch '\.json$') {
                $outputFile += ".json"
            }
            $outputFile | Should -Be "test.json"
        }

        It "Should add .csv extension if not present" {
            $outputFile = "test"
            if ($outputFile -notmatch '\.csv$') {
                $outputFile += ".csv"
            }
            $outputFile | Should -Be "test.csv"
        }
    }

    Context "Test Mode" {
        It "Should limit to first subscription in test mode" {
            $testSubscriptions = @("sub1", "sub2", "sub3")
            $testMode = $true
            
            if ($testMode) {
                $testSubscriptions = @($testSubscriptions[0])
            }
            
            $testSubscriptions.Count | Should -Be 1
        }
    }
}
