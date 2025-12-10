# 3-CostInformation 
Cost data retrieval and region comparison

### Get-CostInformation.ps1

This script is intended to take a collection of given resource IDs and return the cost incurred during previous months, grouped as needed. For this we use the Microsoft.CostManagement provider of each subscription. This means one call of the Cost Management PowerShell module per subscription.

The input file is produced by the Get-AzureServices.ps1 script.

Requires Az.CostManagement module version 0.4.2.

`PS1> Install-Module -Name Az.CostManagement`

Instructions for use:

1. Log on to Azure using `Connect-AzAccount`. Ensure that you have Cost Management Reader access to each subscription listed in the resources file (default `resources.json`)
2. Navigate to the 3-CostInformation folder and run the script using `.\Get-CostInformation.ps1`. The script will generate a CSV file in the current folder.

#### Documentation links - cost retrieval
Documentation regarding the Az.CostManagement module is not always straightforward. Helpful links are:

| Documentation | Link |
| -------- | ------- |
| Cost Management Query (API) | [Link](https://learn.microsoft.com/en-us/rest/api/cost-management/query/usage) |
| Az.CostManagement Query (PowerShell) | [Link](https://learn.microsoft.com/en-us/powershell/module/az.costmanagement/invoke-azcostmanagementquery) |

Valid dimensions for grouping are:

``` text
AccountName
BenefitId
BenefitName
BillingAccountId
BillingMonth
BillingPeriod
ChargeType
ConsumedService
CostAllocationRuleName
DepartmentName
EnrollmentAccountName
Frequency
InvoiceNumber
MarkupRuleName
Meter
MeterCategory
MeterId
MeterSubcategory
PartNumber
PricingModel
PublisherType
ReservationId
ReservationName
ResourceGroup
ResourceGroupName
ResourceGuid
ResourceId
ResourceLocation
ResourceType
ServiceName
ServiceTier
SubscriptionId
SubscriptionName
```

### Perform-RegionComparison.ps1

This script builds on the collection step by comparing pricing across Azure regions for the meter ID's retrieved earlier.
The Azure public pricing API is used, meaning that:
* No login is needed for this step
* Prices are *not* customer-specific, but are only used to calculate the relative cost difference between regions for each meter

As customer discounts tend to be linear (for example, ACD is a flat rate discount across all PAYG Azure spend), the relative price difference between regions can still be used to make an intelligent estimate of the cost impact of a workload move.

Instructions for use:

1. Prepare a list of target regions for comparison. This can be provided at the command line or stored in a variable before calling the script.
2. Ensure the `resources.json` file is present (from the running of the collector script).
2. Run the script using `.\Perform-RegionComparison.ps1`. The script will generate output files in the current folder.

### Multiple Regions Example

```powershell
$regions = @("eastus", "brazilsouth", "australiaeast")
.\Perform-RegionComparison.ps1 -regions $regions -outputType json
```

#### Outputs

Depending on the chosen output format, the script outputs four sets of data:

| Dataset | Contents |
| -------- | ------- |
| `inputs` | The input data used for calling the pricing API (for reference only) |
| `pricemap` | An overview of which regions are cheaper / similarly-priced / more expensive for each meter ID |
| `prices` | Prices for each source/target region mapping by meter ID |
| `uomerrors` | A list of any eventual mismatches of Unit Of Measure between regions |
<!-- | `savings` | An estimate of the potential savings for each target region | -->

#### Documentation links - region comparison

| Documentation | Link |
| -------- | ------- |
| Azure pricing API | [Link](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices) |
