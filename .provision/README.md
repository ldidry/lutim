## ansible-role-lutim

An ansible role deploy the application on host machine(Ubuntu 20.04)

## terraform-aws-lutim

A terraform plan creates necessary AWS infrastructure and deploy the lutim. This terraform plan uses the `lutim_startup.sh` script to deploy lufi on AWS and also uses above ansible role `ansible-role-lutim` to configure the application on AWS.