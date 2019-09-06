output "public_key_pem" {
  value = "${data.terraform_remote_state.vpc.public_key_pem}"
}

output "private_key_filename" {
  value = "${data.terraform_remote_state.vpc.private_key_filename}"
}

output "private_key_pem" {
  value = "${data.terraform_remote_state.vpc.private_key_pem}"
}

output "my_bastion_public_ips" {
  value = "${data.terraform_remote_state.vpc.bastion_ips_public}"
}
