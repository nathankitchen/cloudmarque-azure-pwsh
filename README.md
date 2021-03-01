# Cloudmarque PowerShell Tools for Azure
This repo contains the source code for a PowerShell module used to deploy Azure resources consistent with [Cloudmarque](https://docs.trustmarque.com/cloudmarque). It leverages Azure PowerShell and ARM templates to quickly deploy new resources in a scalable, code-first manner.

## Cloudmarque
Cloudmarque is an open-source reference architecture, operating model, and toolset designed to allow cloud environments to be easily provisioned and managed through code. Cloudmarque documentation is posted on [docs.trustmarque.com](https://docs.trustmarque.com/cloudmarque) with content hosted on [GitHub](https://github.com/Trustmarque/cloudmarque-docs/).

The tools in this repository are versioned and published to the [PowerShell Gallery](https://www.powershellgallery.com/packages/Cloudmarque.Azure/).

Releases are managed as GitHub [Milestones](https://github.com/Trustmarque/cloudmarque-azure-pwsh/milestones).

## Getting started
For more information on using the tools in a local environment or deployment pipeline please refer to the published documentation:

 - [Local installation](https://docs.trustmarque.com/cloudmarque/tools/azure/install.html)
 - [Pipeline usage](https://docs.trustmarque.com/cloudmarque/tools/azure/pipelines.html)

Information on [Contributing to tooling](https://docs.trustmarque.com/cloudmarque/tools/azure/contributing.html) can be found in the same place.

## Cmdlet documentation
Each PowerShell Cmdlet is passed a structured set of parameters which are validated by [JsonSchema](https://json-schema.org/), providing a standardised approach to settings verification. Parameters can be passed to Cmdlets via YAML, JSON, or a PSObject.

JSON Schema is processed as part of the deployment pipeline and merged with Cmdlet help documentation to generate a [Command Reference](https://docs.trustmarque.com/cloudmarque/reference/commands/).

## About
Cloudmarque documentation and tooling is maintained by [Trustmarque](https://www.trustmarque.com/) (Part of Capita PLC). Please see LICENSE.md for more information on open source licenses.