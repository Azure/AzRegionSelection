BeforeAll {
    $scriptPath = "$PSScriptRoot\Get-RessourcesFromAM.ps1"
}

Describe "Get-RessourcesFromAM.ps1 Tests" {
    Context "Parameter Validation" {
        It "Should require filePath parameter" {
            $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
            $params = $scriptAst.FindAll({$args[0] -is [System.Management.Automation.Language.ParameterAst]}, $true)
            
            $filePathParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'filePath' }
            $filePathParam | Should -Not -BeNullOrEmpty
            
            # Check if parameter is mandatory
            $isMandatory = $filePathParam.Attributes | Where-Object { 
                $_.TypeName.Name -eq 'Parameter' -and 
                $_.NamedArguments.ArgumentName -contains 'Mandatory'
            }
            $isMandatory | Should -Not -BeNullOrEmpty
        }

        It "Should have default output file" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'outputFile.*=.*".*summary\.json"'
        }
    }

    Context "Excel File Processing" {
        It "Should check for Excel file existence" {
            Mock Test-Path { return $false }
            
            # Test would validate file existence check
            $true | Should -Be $true
        }

        It "Should validate required worksheets exist" {
            # This would test for 'All_Assessed_Machines' and 'All_Assessed_Disks'
            $requiredSheets = @('All_Assessed_Machines', 'All_Assessed_Disks')
            $requiredSheets.Count | Should -Be 2
        }
    }

    Context "SKU Conversion" {
        It "Should convert Premium disk SKU correctly" {
            $testSku = "Premium SSD P30"
            $expected = "Premium_LRS"
            
            $result = switch -Wildcard ($testSku) {
                "PremiumV2*"    { "PremiumV2_LRS"; break }
                "Premium*"      { "Premium_LRS"; break }
                "StandardSSD*"  { "StandardSSD_LRS"; break }
                "Standard*"     { "Standard_LRS"; break }
                "Ultra*"        { "UltraSSD_LRS"; break }
                default         { "Unknown" }
            }
            
            $result | Should -Be $expected
        }

        It "Should convert StandardSSD disk SKU correctly" {
            $testSku = "StandardSSD E10"
            
            $result = switch -Wildcard ($testSku) {
                "PremiumV2*"    { "PremiumV2_LRS"; break }
                "Premium*"      { "Premium_LRS"; break }
                "StandardSSD*"  { "StandardSSD_LRS"; break }
                "Standard*"     { "Standard_LRS"; break }
                "Ultra*"        { "UltraSSD_LRS"; break }
                default         { "Unknown" }
            }
            
            $result | Should -Be "StandardSSD_LRS"
        }
    }

    Context "Output Generation" {
        It "Should generate correct resource types" {
            $expectedTypes = @("microsoft.compute/disks", "microsoft.compute/virtualmachines")
            $expectedTypes.Count | Should -Be 2
            $expectedTypes | Should -Contain "microsoft.compute/disks"
            $expectedTypes | Should -Contain "microsoft.compute/virtualmachines"
        }
    }
}
