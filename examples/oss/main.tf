module "asg-elb-service" {
  source        = "github.com/ppresto/tf-aws-asg"
  name          = "${var.name_prefix}"
  instance_type = "t2.micro"
  min_size      = "1"
  max_size      = "3"
  server_port   = "8000"
  elb_port      = "80"
}

variable "name_prefix" {
  description = "The name for the ASG. This name is also used to namespace all the other resources created by this module."
  type        = string
  default     = "ppresto-std-asg"
}

output "url" {
  value = module.asg-elb-service.url
}

output "elb_dns_name" {
  value = module.asg-elb-service.elb_dns_name
}

output "asg_name" {
  value = module.asg-elb-service.asg_name
}

output "asg_security_group_id" {
  value = module.asg-elb-service.asg_security_group_id
}

output "elb_security_group_id" {
  value = module.asg-elb-service.elb_security_group_id
}