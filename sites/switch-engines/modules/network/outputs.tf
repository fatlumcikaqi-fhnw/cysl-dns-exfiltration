output "network_id" {
  description = "ID of the private tenant network"
  value       = openstack_networking_network_v2.private.id
}

output "subnet_id" {
  description = "ID of the private subnet"
  value       = openstack_networking_subnet_v2.private.id
}

output "subnet_cidr" {
  description = "Private subnet CIDR"
  value       = openstack_networking_subnet_v2.private.cidr
}

output "router_id" {
  description = "ID of the main router"
  value       = openstack_networking_router_v2.main.id
}

output "external_network_id" {
  description = "ID of the external (public) network"
  value       = data.openstack_networking_network_v2.external.id
}
