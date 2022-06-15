# FME Server (Distributed deployment, Windows)

These terraform scripts deploy [FME Server (Distributed deployment, Windows)](https://azuremarketplace.microsoft.com/en-US/marketplace/apps/safesoftwareinc.fme-server-distributed-deployment?tab=overview) in your Azure Subscription. The scripts can be used as a boilerplate for automic deployments of the public FME Server Azure VM images in your own environment with your own configurations. The terraform scripts are split up into multiple modules to reflect the distributed architecture and to simplify modification of the resources for different scenarios.

# How to use the scripts
## Quickstart
### Prerequisites

To deploy FME Server (Distributed deployment, Windows) on Microsoft Azure from a local machine, the Azure CLI and terraform need to be installed, configured and terraform needs to be authenticated to Azure. Follow this documentation depending on your scenario: [Quickstart: Install and Configure Terraform](https://docs.microsoft.com/en-us/azure/developer/terraform/quickstart-configure)

### Apply the deployment

Once all prerequistes are installed you confirmed that terraform successfully authenticated to Azure the terraform scripts can be deployed via the following steps

1. Review the `variables.tf` file. This file contains all variables for the deployment. Most of the variables have default values assinged, but can be changed in the `.tf` file or overridden by using the `-var` flag with the `terraform apply` command. You will be prompted for any variable that does not have a default after running the `terraform apply` command.
2. Run `terrafom apply` in your console from the directory that that holds the `main.tf` and `variables.tf` file and provide any variables you are prompted for.
3. Review the deployment plan. If the terraform script and the provided variables validated successfully the deployment plan will be output in the consoled for you to review. Additionally you will be prompted wether you want to go ahead with the deployment. If everything looks ok, go ahead with `yes`. The deployment will now provision and configure all neccessary Azure resources and start up FME Server. This will take about 10 - 20 minutes.
4. In this quickstart exmaple the terraform statefile `terraform.tfsate` will be created on on your local machine, so you can review the current state of your deployment and test the deployment. For any productive deployments it is highly recommended to not store the state file locally but in a remote location. This makes sure you can collaborate on the state and any sensitive data contained in the state file will only be accessible to authorized users. To use Azure storage as a backend for your statefile follow this documentation: [Azure storage terraform backend](https://www.terraform.io/language/settings/backends/azurerm)

### Test FME Server

Once the depl0yment is complete it is time to test FME Server. The public URL for the new FME Server can be found in the overview of the Application Gateway resource. Follow these steps to test FME Server:
1. [Log on to the Web User Interface](https://docs.safe.com/fme/html/FME_Server_Documentation/AdminGuide/Log-on-Get-Started-2-Tier.htm)
2. [Request and Install a License](https://docs.safe.com/fme/html/FME_Server_Documentation/AdminGuide/Request_and_Install_a_License-2-Tier.htm)
3. [Run Workspace](https://docs.safe.com/fme/html/FME_Server_Documentation/WebUI/Run-Workspace.htm?)

### Delete the deployment

To remove the FME Server deployment run `terrform destroy` in your console and confirm the prompt with `yes`.

## Modifying resources
The terraform scripts provide an easy way to read and modify the configuration.
### Changing Resource configurations
### Changing backend DB configuration