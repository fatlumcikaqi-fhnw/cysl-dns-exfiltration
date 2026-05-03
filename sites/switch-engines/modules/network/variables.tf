variable "project_name" {
  description = "Project name — used as prefix for all resource names"
  type        = string
}

variable "external_network_name" {
  description = "Name of the existing external/public network in Switch Engines"
  type        = string
}

variable "private_subnet_cidr" {
  description = "Single private IPv4 CIDR for all VMs (e.g. 10.10.1.0/24)"
  type        = string
}
