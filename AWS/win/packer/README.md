#packer scripts to create AMIs for a distributed FME Server deployment
## How to use the scripts
### Prerequisites
1. [Install packer](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli?in=packer/aws-get-started)
2. [Authenticate to AWS](https://learn.hashicorp.com/tutorials/packer/aws-get-started-build-image?in=packer/aws-get-started#authenticate-to-aws)
3. Make sure there is a default VPC with a default subnet available in the region you want to create your AMI. Alternativley a VPC & a subnet ID can be specified in the run configuration. For more details review this [documentation](https://www.packer.io/plugins/builders/amazon/ebs)
### Create the AMIs
1. Open a command line in the packer directory (directory with .pkr.hcl files)
2. Run `packer init`
3. Run `packer validate fme_core.pkr.hcl`
4. Run `packer build fme_core.pkr.hcl`
5. Repeat step 3 and 4 with 3. Run `fme_engine.pkr.hcl`
### Modifiying the AMIs