variable "project_name" {
  description = "Project name — used as prefix for security group names"
  type        = string
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR — used for intra-subnet rules"
  type        = string
}
