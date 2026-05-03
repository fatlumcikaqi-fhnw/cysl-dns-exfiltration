variable "instances" {
  description = "Map of instances to provision"
  type = map(object({
    flavor_name = string
    floating_ip = bool
    fixed_ip    = optional(string)
    user_data   = optional(string, "")
  }))
}

variable "image_name" {
  description = "OS image name for all instances"
  type        = string
}

variable "keypair_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key material"
  type        = string
  sensitive   = true
}

variable "network_id" {
  description = "Private network ID to attach instances to"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for instance ports"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for instance ports"
  type        = string
}

variable "floating_ip_pool" {
  description = "Name of the external floating IP pool (Switch Engines: public)"
  type        = string
  default     = "public"
}
