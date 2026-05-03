output "floating_ips" {
  description = "Public floating IPs — keyed by instance name"
  value = {
    for name, fip in openstack_networking_floatingip_v2.fip :
    name => fip.address
  }
}

output "instance_ips" {
  description = "Private network IPs — keyed by instance name"
  value = {
    for name, vm in openstack_compute_instance_v2.vm :
    name => vm.access_ip_v4
  }
}

output "instance_ids" {
  description = "OpenStack instance UUIDs — keyed by instance name"
  value = {
    for name, vm in openstack_compute_instance_v2.vm :
    name => vm.id
  }
}
