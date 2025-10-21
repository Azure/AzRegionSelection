# Welcome to the Region Selection toolkit wiki

This wiki documents the current situation during the development of the Region Selection toolkit.

# What is Regions selection toolkit

## Project Description

**Region Selection Toolkit** is a comprehensive solution for guiding Cloud Solution Architects, Solution Engineers and IT teams in selecting the optimal Microsoft Azure region for their workloads. This toolkit automates the complex analysis required when deciding “Which Azure region should we deploy to?”. It evaluates multiple factors – from service availability and compliance to sustainability and performance – to recommend the best region(s) for a given set of cloud resources. The goal is to streamline regional planning for scenarios such as migrating to a new Azure region, expanding an application into additional regions, or choosing a region for a new deployment.

This holistic approach ensures you consider all angles (technical, business, and environmental) when comparing cloud regions.

*Note: The Region Selection Toolkit is designed with extensibility in mind. Its modular architecture means additional factors (e.g. capacity planning data or more detailed latency testing) can be incorporated over time. New Azure regions and services are continually updated to keep recommendations current.*

## Toolkit Features

**Inventory collection**
The toolkit can collect an inventory of your existing Azure resources (e.g. via Azure Resource Graph) or accept input from an Azure Migrate assessment. This inventory forms the basis of the region compatibility analysis.

**Multi-Factor Region Analysis**
Analyses Azure regions against a wide range of criteria crucial for decision-making. 
It checks:

* Service Availability & Roadmap
  Verifies that all Azure services and features used by your workload are available (or have planned availability) in the target region. The toolkit cross-references your workload’s resource types against Azure’s regional services list, helping avoid deployments in regions where required services are not yet supported.

* cost differences
  Compares estimated costs of running the workload in different regions. Azure service pricing can vary by region; the toolkit retrieves pricing information for your workload’s resource mix in each candidate region, allowing a side-by-side cost comparison. This helps in budgeting and choosing a cost-effective location without manual price research.

* Compliance and geopolitical factors [V1]
  Takes into account data residency requirements and geopolitical considerations. It will flag, for instance, if a region belongs to a specific sovereignty (such as EU, US Gov, or China regions) or if there are legal/regulatory implications in choosing that location. This ensures your region choice aligns with compliance mandates and organisational policies (e.g. GDPR, data sovereignty, or other regional regulations).

* performance impacts [V2]
  Provides insights on performance-related aspects such as network latency and infrastructure resiliency. For example, it notes whether a region offers Availability Zones and identifies the region’s paired region (for disaster recovery purposes). This helps evaluate reliability and potential latency impact on end-users when moving or expanding to that region.

* and sustainability metrics [V1]
  Highlights sustainability considerations of each region. The toolkit surfaces data like regional carbon intensity or renewable energy availability (where available) to help organisations optimise for lower carbon footprint. Choosing a greener Azure region can support corporate sustainability goals – the toolkit makes this information readily accessible during planning.

for each potential region.

**Recommendation Report**

 After analysis, the toolkit produces a clear report or summary of findings. You’ll get a list of recommended region(s) ranked or filtered based on the defined criteria, along with the reasoning (e.g. “Region A is recommended due to full service availability and lowest cost, with moderate sustainability score”). This report can be used to present options to stakeholders or as a blueprint for the actual migration/deployment.
