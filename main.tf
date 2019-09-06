# PROVIDER CONFIGURATION - AWS
provider "aws" {
  region = "${var.region}"
}

# Get Network VPC Workspace Outputs
#
#        All needed outputs could be obtained with this data source alone.  
#        We added an additional variable below "var.vpc_id" to force/show interpolation input in the UI Config Designer
#        Example UI Input: ${data.terraform_remote_state.tfeOrg_workspaceName.attribute}
#
#  BUG: The UI Configuration Designer appears to have a Bug in the generated data source output.  Add "https://" to the address.
#       address = "https://app.terraform.io"
#

data "terraform_remote_state" "vpc" {
  backend = "remote"

  config = {
    hostname     = "${var.tfe_host}"
    organization = "${var.tfe_org}"

    workspaces = {
      name = "${var.tfe_workspace}"
    }
  }
}

module "consul_auto_join_instance_role" {
  source = "github.com/hashicorp-modules/consul-auto-join-instance-role-aws"

  create = "${var.count > 0 ? 1 : 0}"
  name   = "${var.name_prefix}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

data "template_file" "node_init" {
  count    = "${var.count > 0 ? 1 : 0}"
  template = "${file("${path.module}/templates/init-systemd.sh.tpl")}"

  vars = {
    name      = "${var.name_prefix}"
    user_data = "${var.user_data != "" ? var.user_data : "echo 'No custom user_data'"}"
  }
}

resource "aws_launch_configuration" "nodes" {
  count = "${var.count > 0 ? 1 : 0}"

  name_prefix                 = "${format("%s-node-", var.name_prefix)}"
  associate_public_ip_address = "${var.public}"
  ebs_optimized               = false
  instance_type               = "${var.instance_type}"
  image_id                    = "${var.image_id != "" ? var.image_id : element(concat(data.aws_ami.ubuntu.*.id, list("")), 0)}" # TODO: Workaround for issue #11210
  iam_instance_profile        = "${var.instance_profile != "" ? var.instance_profile : module.consul_auto_join_instance_role.instance_profile_id}"
  user_data                   = "${data.template_file.node_init.rendered}"
  key_name                    = "${data.terraform_remote_state.vpc.ssh_key_name}"

  security_groups = [
    "${aws_security_group.app.id}",
  ]

  lifecycle {
    create_before_destroy = true
  }
}

module "consul_lb_aws" {
  source = "github.com/hashicorp-modules/consul-lb-aws"
  #source = "../consul-lb-aws"

  create             = "${var.count > 0 ? true : false}"
  name               = "${var.name_prefix}"
  vpc_id             = "${data.terraform_remote_state.vpc.vpc_id}"
  cidr_blocks        = ["${var.public ? "0.0.0.0/0" : data.terraform_remote_state.vpc.vpc_cidr}"] # If there's a public IP, open port 22 for public access - DO NOT DO THIS IN PROD
  subnet_ids         = ["${split(",", var.public ? join(",", data.terraform_remote_state.vpc.subnet_public_ids) : join(",", data.terraform_remote_state.vpc.subnet_private_ids))}"]
  #subnet_ids         = ["${var.public ? data.terraform_remote_state.vpc.subnet_public_ids : data.terraform_remote_state.vpc.subnet_private_ids}"]
  #is_internal_lb     = "${!var.public}"
  #use_lb_cert        = "${var.use_lb_cert}"
  #lb_cert            = "${var.lb_cert}"
  #lb_private_key     = "${var.lb_private_key}"
  #lb_cert_chain      = "${var.lb_cert_chain}"
  #lb_ssl_policy      = "${var.lb_ssl_policy}"
  #lb_bucket          = "${var.lb_bucket}"
  #lb_bucket_override = "${var.lb_bucket_override}"
  #lb_bucket_prefix   = "${var.lb_bucket_prefix}"
  #lb_logs_enabled    = "${var.lb_logs_enabled}"
  tags               = "${var.tags}"
}

resource "aws_autoscaling_group" "nodes" {
  count = "${var.count > 0 ? 1 : 0}"

  name_prefix          = "${aws_launch_configuration.nodes.name}"
  launch_configuration = "${aws_launch_configuration.nodes.id}"
  vpc_zone_identifier  = ["${data.terraform_remote_state.vpc.subnet_public_ids}"]
  max_size             = "${var.count != -1 ? var.count : length(data.terraform_remote_state.vpc.subnet_public_ids)}"
  min_size             = "${var.count != -1 ? var.count : length(data.terraform_remote_state.vpc.subnet_public_ids)}"
  desired_capacity     = "${var.count != -1 ? var.count : length(data.terraform_remote_state.vpc.subnet_public_ids)}"
  default_cooldown     = 30
  force_delete         = true

  target_group_arns = ["${compact(concat(
    list(
      module.consul_lb_aws.consul_tg_http_8500_arn,
      module.consul_lb_aws.consul_tg_https_8080_arn,
    ),
    var.target_groups
  ))}"]

  tags = ["${concat(
    list(
      map("key", "Name", "value", format("%s-consul-node", var.name_prefix), "propagate_at_launch", true),
      map("key", "Consul-Auto-Join", "value", var.name_prefix, "propagate_at_launch", true)
    ),
    var.tags_list
  )}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app" {
  count       = "${var.count > 0 ? 1 : 0}"
  name_prefix = "${var.name_prefix}-sg"
  description = "${var.name_prefix} security group"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"
  tags        = "${merge(var.tags, map("Name", format("%s-mynode", var.name_prefix)))}"
}

resource "aws_security_group_rule" "ssh" {
  count             = "${var.count > 0 ? 1 : 0}"
  security_group_id = "${aws_security_group.app.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["${var.ingress_cidr_block}"]
}

resource "aws_security_group_rule" "http" {
  count             = "${var.count > 0 ? 1 : 0}"
  security_group_id = "${aws_security_group.app.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "${var.http_port}"
  to_port           = "${var.http_port}"
  cidr_blocks       = ["${var.ingress_cidr_block}"]
}

resource "aws_security_group_rule" "https" {
  count             = "${var.count > 0 ? 1 : 0}"
  security_group_id = "${aws_security_group.app.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "${var.https_port}"
  to_port           = "${var.https_port}"
  cidr_blocks       = ["${var.ingress_cidr_block}"]
}

resource "aws_security_group_rule" "egress" {
  count             = "${var.count > 0 ? 1 : 0}"
  security_group_id = "${aws_security_group.app.id}"
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["${var.ingress_cidr_block}"]
}
