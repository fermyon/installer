output "ec2_ssh_public_key" {
  description = "The public key for SSH access to the EC2 instance"
  value       = tls_private_key.ec2_ssh_key.public_key_pem
}

output "ec2_ssh_private_key" {
  description = "The private key for SSH access to the EC2 instance"
  value       = tls_private_key.ec2_ssh_key.private_key_pem
  sensitive   = true
}

output "eip_public_ip_address" {
  description = "The public IP address associated with the EC2 instance"
  value       = aws_eip.lb.public_ip
}

output "dns_host" {
  description = "The DNS host to use for construction of the root domain for Fermyon Platform services and apps"
  value       = var.dns_host
}

output "bindle_url" {
  description = "The URL for the Bindle server"
  value       = aws_eip.lb.public_ip == "sslip.io" ? "https://bindle.${aws_eip.lb.public_ip}.${var.dns_host}/v1" : "https://bindle.${var.dns_host}/v1"
}

output "hippo_url" {
  description = "The URL for the Hippo server"
  value       = aws_eip.lb.public_ip == "sslip.io" ? "https://hippo.${aws_eip.lb.public_ip}.${var.dns_host}" : "https://hippo.${var.dns_host}"
}

output "hippo_admin_username" {
  description = "Admin username for Hippo when running in AdministratorOnly mode"
  value       = var.hippo_admin_username
}

output "hippo_admin_password" {
  description = "Admin password for Hippo when running in AdministratorOnly mode"
  value       = random_password.hippo_admin_password.result
  sensitive   = true
}
