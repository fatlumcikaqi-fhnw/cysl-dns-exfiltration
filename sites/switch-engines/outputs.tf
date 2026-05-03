output "public_ips" {
  description = "Public floating IPs assigned to each instance (only instances with floating_ip = true)"
  value       = module.compute.floating_ips
}

output "floating_ips" {
  description = "Public floating IPs assigned to each instance (only instances with floating_ip = true)"
  value       = module.compute.floating_ips
}

output "private_ips" {
  description = "Private network IPs of all instances"
  value       = module.compute.instance_ips
}

output "instance_ips" {
  description = "Private network IPs of all instances"
  value       = module.compute.instance_ips
}

output "network_id" {
  description = "ID of the private tenant network"
  value       = module.network.network_id
}

output "subnet_id" {
  description = "ID of the private subnet"
  value       = module.network.subnet_id
}

output "subnet_cidr" {
  description = "Private subnet CIDR"
  value       = module.network.subnet_cidr
}

output "security_group_id" {
  description = "ID of the main security group"
  value       = module.security_groups.security_group_id
}
