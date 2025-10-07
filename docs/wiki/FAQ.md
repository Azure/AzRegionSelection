# Frequently Asked Questions

Does the Azure to Azure migration toolkit work on Mac?
    Yes it does.

    - Follow the below steps as pre-requisites so that you can successfully use A2ATK on a Mac.

1. Install homebrew if you do not have it. Open a terminal and run

/bin/bash -c "$(curl -fsSL [https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh](https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh))"

More info can be found here: [https://brew.sh/](https://brew.sh/)

1. Once homebrew is installed, Install PowerShell.

brew install powershell

3. The executable to get into PowerShell is "pwsh". In a terminal you can type "pwsh" and you will get a PowerShell prompt.

└🤘-> pwsh
PowerShell 7.5.2
PS /Users/user>

4. Now install the required modules.

    Install-Module Az (This is the Azure PowerShell Module)
    Import-Module Az (Import the module)
    Install-Module -Name Az.CostManagement (This is the Azure Cost Management PowerShell Module)
    Import-Module Az.CostManagement (Import the module)
    Install-Module -Name ImportExcel (This is the Excel PowerShell Module) - So that it can export to Excel correctly.

    One last package that needs to be installed to get the Excel formatting done correctly is mono-libgdiplus
    You can do this by running

    brew install mono-libgdiplus

Now just follow the rest of the steps in the Docs as if you were running Windows. All the commands will work in pwsh from the Mac terminal.