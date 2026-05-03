# SSH and ICMP from any IPv4; full east-west within the private subnet; egress allow-all is default on SGs.

resource "openstack_networking_secgroup_v2" "main" {
  name        = "${var.project_name}-sg"
  description = "SSH (22) and ICMP from anywhere; all protocols within private subnet"
}

resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

resource "openstack_networking_secgroup_rule_v2" "private_subnet" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_ip_prefix  = var.private_subnet_cidr
  security_group_id = openstack_networking_secgroup_v2.main.id
  description       = "All traffic from the private subnet (VM-to-VM)"
}
