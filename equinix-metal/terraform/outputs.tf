output "ssh_public_key" {
  description = "The public key for SSH access to the server"
  value       = tls_private_key.ssh_key.public_key_pem
}

output "ssh_private_key" {
  description = "The private key for SSH access to the server"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}

output "public_ip_address" {
  description = "The Global IP address"
  value       = equinix_metal_reserved_ip_block.global_ip.network
}

output "regional_ip_addresses" {
  description = "Regional IP addresses"
  value = tomap({
    for k, device in equinix_metal_device.fermyon : k => device.access_public_ipv4
  })
}

output "dns_host" {
  description = "The DNS host to use for construction of the root domain for Fermyon Platform services and apps"
  value       = var.dns_host
}

output "bindle_url" {
  description = "The URL for the Bindle server"
  value       = "${var.enable_letsencrypt ? "https" : "http"}://bindle.${var.dns_host == "sslip.io" ? "${equinix_metal_reserved_ip_block.global_ip.network}.${var.dns_host}" : var.dns_host}/v1"
}

output "hippo_url" {
  description = "The URL for the Hippo server"
  value       = "${var.enable_letsencrypt ? "https" : "http"}://hippo.${var.dns_host == "sslip.io" ? "${equinix_metal_reserved_ip_block.global_ip.network}.${var.dns_host}" : var.dns_host}"
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

output "environment" {
  description = "Get environment config by running: $(terraform output -raw environment)"
  sensitive   = true
  value       = <<EOM
export DNS_DOMAIN=${var.dns_host == "sslip.io" ? "${equinix_metal_reserved_ip_block.global_ip.network}.${var.dns_host}" : var.dns_host}
export HIPPO_URL=${var.enable_letsencrypt ? "https" : "http"}://hippo.${var.dns_host == "sslip.io" ? "${equinix_metal_reserved_ip_block.global_ip.network}.${var.dns_host}" : var.dns_host}
export HIPPO_USERNAME=${var.hippo_admin_username}
export HIPPO_PASSWORD=${random_password.hippo_admin_password.result}
export BINDLE_URL=${var.enable_letsencrypt ? "https" : "http"}://bindle.${var.dns_host == "sslip.io" ? "${equinix_metal_reserved_ip_block.global_ip.network}.${var.dns_host}" : var.dns_host}/v1

EOM
}
