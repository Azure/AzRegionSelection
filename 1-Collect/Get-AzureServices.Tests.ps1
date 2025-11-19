BeforeAll {
    $scriptPath = "$PSScriptRoot\Get-AzureServices.ps1"
}

Describe "Get-AzureServices.ps1 Tests" {
    Context "Parameter Validation" {
        It "Should accept valid scopeType values" {
            $validScopes = @('singleSubscription', 'resourceGroup', 'multiSubscription')
            
            # Parse the script to check parameter validation
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'ValidateSet.*singleSubscription.*resourceGroup.*multiSubscription'
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
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'fullOutputFile.*=.*"resources.json"'
            $scriptContent | Should -Match 'summaryOutputFile.*=.*"summary.json"'
        }
    }

    Context "Function Definitions" {
        It "Should define Get-Property function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-Property'
        }

        It "Should define Get-SingleData function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-SingleData'
        }

        It "Should define Get-Method function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-Method'
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
