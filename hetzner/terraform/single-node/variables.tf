variable "hcloud_token" {
  default     = ""
  description = "Hetzner Cloud API token"
}

variable "prefix" {
  type    = string
  default = "provisioned-with-terraform"
}


variable "server_name" {
  description = "The name of the server; should be unique if multiple are launched in the same region"
  type        = string
  default     = "fermyon"
}

/*
$ hcloud location list
ID   NAME   DESCRIPTION             NETWORK ZONE   COUNTRY   CITY
1    fsn1   Falkenstein DC Park 1   eu-central     DE        Falkenstein
2    nbg1   Nuremberg DC Park 1     eu-central     DE        Nuremberg
3    hel1   Helsinki DC Park 1      eu-central     FI        Helsinki
4    ash    Ashburn, VA             us-east        US        Ashburn, VA
5    hil    Hillsboro, OR           us-west        US        Hillsboro, OR
*/

variable "server_location" {
  description = "Location of the server"
  type        = string
  default     = "nbg1"
}

/*
$ hcloud server-type list | grep shared
1    cx11    1       shared      2.0 GB     20 GB    local
3    cx21    2       shared      4.0 GB     40 GB    local
5    cx31    2       shared      8.0 GB     80 GB    local
7    cx41    4       shared      16.0 GB    160 GB   local
9    cx51    8       shared      32.0 GB    240 GB   local
22   cpx11   2       shared      2.0 GB     40 GB    local
23   cpx21   3       shared      4.0 GB     80 GB    local
24   cpx31   4       shared      8.0 GB     160 GB   local
25   cpx41   8       shared      16.0 GB    240 GB   local
26   cpx51   16      shared      32.0 GB    360 GB   local
*/

variable "server_type" {
  description = "The type of server to run for each node in the cluster (Default: cx11)"
  type        = string
  default     = "cx11"
}

variable "enable_letsencrypt" {
  description = "Enable cert provisioning via Let's Encrypt"
  type        = bool
  default     = false
}

variable "dns_host" {
  description = "The DNS host to use for construction of the root domain for Fermyon Platform services and apps"
  type        = string
  default     = "sslip.io"
}

variable "allowed_ssh_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the server will allow SSH connections"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_inbound_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the server will allow connections"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allow_outbound_cidr_blocks" {
  description = "Allow outbound traffic to these CIDR blocks"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allow_inbound_http_nomad" {
  description = "Allow inbound connections to the unsecured Nomad API http port"
  type        = bool
  default     = false
}

variable "allow_inbound_http_consul" {
  description = "Allow inbound connections to the unsecured Consul API http port"
  type        = bool
  default     = false
}

variable "hippo_admin_username" {
  description = "Admin username for Hippo when running in AdministratorOnly mode"
  type        = string
  default     = "admin"
}

variable "hippo_registration_mode" {
  description = "The registration mode for Hippo. Options are 'Open', 'Closed' and 'AdministratorOnly'. (Default: AdministratorOnly)"
  type        = string
  default     = "AdministratorOnly"

  validation {
    condition     = var.hippo_registration_mode == "Open" || var.hippo_registration_mode == "Closed" || var.hippo_registration_mode == "AdministratorOnly"
    error_message = "The Hippo registration mode must be 'Open', 'Closed' or 'AdministratorOnly'."
  }
}
