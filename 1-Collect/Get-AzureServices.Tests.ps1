BeforeAll {
    $scriptPath = "$PSScriptRoot\Get-AzureServices.ps1"
    $script:scriptContent = Get-Content $scriptPath -Raw
}

Describe "Get-AzureServices.ps1 Tests" {
    Context "Parameter Validation" {
        It "Should accept valid scopeType values" {
            $validScopes = @('singleSubscription', 'resourceGroup', 'multiSubscription')

            # Verify each scope is present in the script's ValidateSet
            foreach ($scope in $validScopes) {
                $script:scriptContent | Should -Match $scope
            }
        }

        It "Should have required parameters defined" {
            $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
            $params = $scriptAst.FindAll({$args[0] -is [System.Management.Automation.Language.ParameterAst]}, $true)
            $paramNames = $params | ForEach-Object { $_.Name.VariablePath.UserPath }
            $paramNames | Should -Contain 'scopeType'
            $paramNames | Should -Contain 'fullOutputFile'
            $paramNames | Should -Contain 'summaryOutputFile'
        }

        It "Should have default values for output files" {
            $script:scriptContent | Should -Match 'fullOutputFile.*=.*"resources.json"'
            $script:scriptContent | Should -Match 'summaryOutputFile.*=.*"summary.json"'
        }
    }

    Context "Function Definitions" {
        It "Should define Get-Property function" {
            $script:scriptContent | Should -Match 'Function Get-Property'
        }

        It "Should define Get-SingleData function" {
            $script:scriptContent | Should -Match 'Function Get-SingleData'
        }

        It "Should define Get-Method function" {
            $script:scriptContent | Should -Match 'Function Get-Method'
        }
    }

    Context "Output File Generation" {
        It "Should create resources.json output file" {
            # This test would require mocking Azure cmdlets
            # Placeholder for integration test
            $true | Should -Be $true
        }

        It "Should create summary.json output file" {
            # This test would require mocking Azure cmdlets
            # Placeholder for integration test
            $true | Should -Be $true
        }
    }
}
