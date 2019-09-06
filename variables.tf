variable "name_prefix" {
  description = "Enter your name or unique project description here ( default: ppresto-dev-ec2 )"
  default     = "ppresto-dev-ec2"
}

variable "region" {
  description = "Enter AWS Region (default: us-west-2)"
  default     = "us-west-2"
}

variable "public" {
  description = "Instance is accessibly from outside (default: true)"
  default     = true
}

variable "count" {
  description = "# of Instances ( default=1 )"
  default     = 1
}

variable "instance_type" {
  description = "Select Instance Size (default: t2.micro)"
  type        = "string"
  default     = "t2.micro"
}

variable "egress_cidr_block" {
  description = "Outgoing Traffic (Default: 0.0.0.0/0)"
  type        = "string"
  default     = "0.0.0.0/0"
}

variable "ingress_cidr_block" {
  description = "WARNING: USING 0.0.0.0/0 IS INSECURE! (ex: <public.ipaddress>/32)"
  type        = "string"
  default     = "0.0.0.0/0"
}

variable "http_port" {
  description = "Enable HTTP on port (default: 80)"
  default     = 80
}

variable "https_port" {
  description = "Enable HTTPS on port (default: 443)"
  default     = 443
}

variable "tags" {
  description = "Optional map of tags to set on resources, defaults to empty map."
  type        = "map"
  default     = {}
}

variable "tfe_host" {
  description = "Enter your TFE host ( default: app.terraform.io )"
  default     = "app.terraform.io"
}

variable "tfe_org" {
  description = "Enter your TFE organization ( default: Patrick )"
  default     = "Patrick"
}

variable "tfe_workspace" {
  description = "Enter the workspace managing your VPC ( default: tf-aws-standard-network )"
  default     = "tf-aws-standard-network"
}

variable "subnet_id" {
  description = "Enter the subnet_id your nodes should be deployed to (Required Input)"
  default = "subnet-01a9d74a1c6fd5cc3"
}


##############
variable "image_id" {
  description = "AMI to use, defaults to the HashiStack AMI."
  default     = ""
}

variable "instance_profile" {
  description = "AWS instance profile to use, defaults to consul-auto-join-instance-role module."
  default     = ""
}

variable "user_data" {
  description = "user_data script to pass in at runtime."
  default     = ""
}

variable "target_groups" {
  description = "List of target group ARNs to apply to the autoscaling group."
  type        = "list"
  default     = []
}

variable "tags_list" {
  description = "Optional list of tag maps to set on resources, defaults to empty list."
  type        = "list"
  default     = []
}
