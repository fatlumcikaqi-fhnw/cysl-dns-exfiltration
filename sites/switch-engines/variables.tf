variable "project_name" {
  description = "Switch Engines OpenStack project name"
  type        = string
}

variable "region" {
  description = "Switch Engines region — ZH (Zurich) or LS (Lausanne)"
  type        = string
  default     = "ZH"
}

variable "keypair_name" {
  description = "Name of the SSH key pair to create in OpenStack"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key material (ed25519 or rsa)"
  type        = string
  sensitive   = true
}

variable "external_network_name" {
  description = "Name of the Switch Engines external/public network"
  type        = string
  default     = "public"
}

variable "private_subnet_cidr" {
  description = "Single private IPv4 CIDR for all VMs (e.g. 10.10.1.0/24)"
  type        = string
}

variable "instances" {
  description = <<-EOT
    Map of compute instances to provision.
    Each entry is one VM: flavor, optional fixed private IP, floating IP, optional cloud-init override.
  EOT
  type = map(object({
    flavor_name = string
    floating_ip = bool
    fixed_ip    = optional(string)
    user_data   = optional(string, "")
  }))
}

variable "image_name" {
  description = "OS image name to use for all instances"
  type        = string
  default     = "Debian Trixie 13 (SWITCHengines)"
}

variable "floating_ip_pool" {
  description = "OpenStack floating IP pool name"
  type        = string
  default     = "public"
}
