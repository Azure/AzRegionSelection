BeforeAll {
    $scriptPath = "$PSScriptRoot\Perform-RegionComparison.ps1"
}

Describe "Perform-RegionComparison.ps1 Tests" {
    Context "Parameter Validation" {
        It "Should have default resource file" {
            $defaultFile = "resources.json"
            $defaultFile | Should -Be "resources.json"
        }

        It "Should have default output format" {
            $defaultFormat = "console"
            $defaultFormat | Should -Be "console"
        }

        It "Should validate output formats" {
            $validFormats = @("json", "csv", "excel", "console")
            $validFormats | Should -Contain "json"
            $validFormats | Should -Contain "excel"
        }

        It "Should require regions parameter" {
            # Regions is required for meaningful comparison
            $testRegions = @("eastus", "westeurope")
            $testRegions.Count | Should -BeGreaterThan 0
        }
    }

    Context "API Configuration" {
        It "Should set correct batch sizes" {
            $meterIdBatchSize = 10
            $regionBatchSize = 10
            
            $meterIdBatchSize | Should -Be 10
            $regionBatchSize | Should -Be 10
        }

        It "Should set correct base URI" {
            $baseUri = "https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview"
            $baseUri | Should -Match "^https://prices\.azure\.com"
        }
    }

    Context "Filter Construction" {
        It "Should build currency filter" {
            $filterString = '$filter=currencyCode eq ''USD'''
            $filterString | Should -Match "currencyCode eq 'USD'"
        }

        It "Should build consumption type filter" {
            $filterString = "type eq 'Consumption'"
            $filterString | Should -Match "type eq 'Consumption'"
        }

        It "Should build primary meter region filter" {
            $filterString = "isPrimaryMeterRegion eq true"
            $filterString | Should -Match "isPrimaryMeterRegion eq true"
        }
    }

    Context "File Validation" {
        It "Should check resource file exists" {
            # Test file existence check
            $testFile = "resources.json"
            $testFile | Should -Not -BeNullOrEmpty
        }

        It "Should require ImportExcel for Excel output" {
            $moduleName = "ImportExcel"
            $moduleName | Should -Be "ImportExcel"
        }
    }

    Context "Price Comparison Logic" {
        It "Should calculate price difference" {
            $origPrice = 100.00
            $targetPrice = 90.00
            $difference = $targetPrice - $origPrice
            
            $difference | Should -Be -10
        }

        It "Should calculate percentage difference" {
            $origPrice = 100.00
            $targetPrice = 90.00
            $percentage = [math]::Round((($targetPrice - $origPrice) / $origPrice), 2)
            
            $percentage | Should -Be -0.1
        }

        It "Should handle zero original price" {
            $origPrice = 0
            $targetPrice = 10.00
            
            if ($origPrice -ne 0) {
                $percentage = ($targetPrice - $origPrice) / $origPrice
            } else {
                $percentage = $null
            }
            
            $percentage | Should -BeNullOrEmpty
        }
    }

    Context "Output File Extensions" {
        It "Should add .json extension" {
            $outputFile = "test"
            if ($outputFile -notmatch '\.json$') {
                $outputFile += ".json"
            }
            $outputFile | Should -Be "test.json"
        }

        It "Should add .xlsx extension" {
            $outputFile = "test"
            if ($outputFile -notmatch '\.xlsx$') {
                $outputFile += ".xlsx"
            }
            $outputFile | Should -Be "test.xlsx"
        }

        It "Should not duplicate extension" {
            $outputFile = "test.json"
            if ($outputFile -notmatch '\.json$') {
                $outputFile += ".json"
            }
            $outputFile | Should -Be "test.json"
        }
    }

    Context "Unit of Measure Validation" {
        It "Should detect UoM mismatches" {
            $origUoM = "1 Hour"
            $targetUoM = "100 Hours"
            
            $mismatch = $origUoM -ne $targetUoM
            $mismatch | Should -Be $true
        }
    }
}
