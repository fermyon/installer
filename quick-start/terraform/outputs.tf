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

output "bindle_url" {
  description = "The URL for the Bindle server"
  value       = "https://bindle.${aws_eip.lb.public_ip}.${var.dns_host}/v1"
}

output "hippo_url" {
  description = "The URL for the Hippo server"
  value       = "https://hippo.${aws_eip.lb.public_ip}.${var.dns_host}"
}

output "basic_auth_username" {
  description = "Username for authenticating with Bindle (basic auth) and Hippo (admin account)"
  value       = var.basic_auth_username
}

output "basic_auth_password" {
  description = "Password for authenticating with Bindle (basic auth) and Hippo (admin account)"
  value       = random_password.basic_auth_password.result
  sensitive   = true
}