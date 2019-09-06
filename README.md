# tf-aws-ec2-instance
This module will build development instance into an existing VPC.  The instances will be directly accessible to the defined ingress cidr block on defined ports (defaults: 22, 80, 443).  These will be running ubuntu.

## Quickstart
```
vi variables.tf
```
* Define your unique name.  This will be used for your resources (name_prefix)
* Get the TFE Workspace name currently managing your Network and update the tfe variables (tfe_workspace, tfe_host, tfe_org)
* Set the number of instance you want to build (count)
* Set a secure ingress CIDR block (ingress_cidr_block).  The default is unsecure (0.0.0.0)
* If you want custom HTTP, and HTTP ports set the http variables (http_port, https_port)

### TFE CLI Demo
Run the simple.sh to walk through setting up your env, building this ec2 instance, and cleaning everything up.
```
./simple.sh
```

Now Queue a Run.

### TFE UI
Log into TFE and build or access the workspace you will use for this excersize

1. Update your workspace with env/terraform variables defined
2. Setup VCS connection to the repo that has your module code.  You can use ./simple/main.tf as a starting point.
3. Queue a run
   
### TFE CLI (manual)
1. create your .terraformrc file to include your TFE credentials with apply privilages**
```
export TERRAFORM_CONFIG=".terraformrc"
export ATLAS_TOKEN="<YOUR_TFE_TOKEN>"

cat <<- CONFIG > ./.terraformrc
credentials "app.terraform.io" {
  token = "${ATLAS_TOKEN}"
}
CONFIG
```

2. run terraform init, plan, apply
```
terraform init
terraform plan
terraform apply -auto-approve
#terraform destroy -auto-approve
```


