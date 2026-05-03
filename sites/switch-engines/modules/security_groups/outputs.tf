output "security_group_id" {
  description = "ID of the main security group"
  value       = openstack_networking_secgroup_v2.main.id
}
