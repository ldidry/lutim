# Terraform-AWS-Deploy

 This terraform plan create the resourcess of EC2 instance

## Terraform Variables
 Edit the `vars.tf` file to add the variables as per your need.

| Variable name | Value | Description |
| ------------- | ----- | ----------- |
| `aws_region` | us-east-1 | Set the region  |
| `vpc_cidr` | 10.0.0.0/16 | Set the cidr value for the vpc |
| `public_subnet_cidr` | 10.0.2.0/24 | Set the cidr value for the public subnet |
| `user` | ubuntu | Set the EC2 instance user name |
| `public_key` | /home/user_name/.ssh/id_rsa_pub | Set the publickey value for the ec2 instance from the host machine |
| `private_key` | /home/user_name/.ssh/id_rsa | Set the private key value for the ec2 instance from the hostmachine |
| `aws_access_key` | AWSACCESSKEY | Enter your aws access key |
| `aws_secrete_key` | AWSSECRETEKEY | Enter your aws secrete key |
| `instance_name` | lutim_app_instance | Set the name for instance |
| `app_dir` | /var/www/lutim | Set the application directory for the best practice |
| `lutim_owner` | www-data | Set the application user for the best practice |
| `lutim_group` | www-data | Set the application group for the best practice |
| `contact` | contact.example.com | Contact option (mandatory), where you have to put some way for the users to contact you. |
| `contact_user` | name | Name of the user |
| `secrets` | ffyg7kbkjba | Secrets option (mandotory), which is array of random string. Used by Mojolicious for encrypting session cookies |
| `app_dir` | /var/www/lutim | Set the application directory for the best practice |
| `lutim_owner` | www-data | Set the application user for the best practice |
| `lutim_group` | www-data | Set the application group for the best practice |
| `contact` | contact.example.com | Contact option (mandatory), where you have to put some way for the users to contact you. |
| `contact_user` | name | Name of the user |
| `secrets` | ffyg7kbkjba | Secrets option (mandotory), which is array of random string. Used by Mojolicious for encrypting session cookies |

## Usage of terraform plan with lufi deploy script

```sh 
git clone https://framagit.org/fiat-tux/hat-softwares/lutim.git

cd lutim/.provision/terraform-aws-lutim

terraform init
terraform plan
terraform apply
```
## Usage of terraform plan with ansible role

- Comment out the below `locals` and `user_data` source in __main.tf__ file

```hcl
locals {
  user_data_vars = {
    user = var.lutim_owner
    group = var.lutim_group
    directory = var.app_dir
    contact_user = var.contact_user
    contact_lutim = var.contact
    secret_lutim = var.secret
  }
}
```

```hcl
user_data  = templatefile("${path.module}/lutim_startup.sh", local.user_data_vars)
```

- Add the below provisioner data in __main.tf__ file at the `aws_instance` resource

```sh
 connection          {
    agent            = false
    type             = "ssh"
    host             = aws_instance.ec2_instance.public_dns 
    private_key      = "${file(var.private_key)}"
    user             = "${var.user}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install python3.9 -y",
      ]
  }

  provisioner "local-exec" {
    command = <<EOT
      sleep 120 && \
      > hosts && \
      echo "[Lutim]" | tee -a hosts && \
      echo "${aws_instance.ec2_instance.public_ip} ansible_user=${var.user} ansible_ssh_private_key_file=${var.private_key}" | tee -a hosts && \
      export ANSIBLE_HOST_KEY_CHECKING=False && \
      ansible-playbook -u ${var.user} --private-key ${var.private_key} -i hosts site.yml
    EOT
  }
```  
