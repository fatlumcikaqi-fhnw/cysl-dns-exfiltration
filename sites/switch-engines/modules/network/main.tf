# Look up the existing external network — not managed by us, just referenced
data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

resource "openstack_networking_network_v2" "private" {
  name           = "${var.project_name}-net"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "private" {
  name            = "${var.project_name}-subnet"
  network_id      = openstack_networking_network_v2.private.id
  cidr            = var.private_subnet_cidr
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]

  # Keep .2–.19 and high range free for router/gateway and fixed instance IPs
  allocation_pool {
    start = cidrhost(var.private_subnet_cidr, 50)
    end   = cidrhost(var.private_subnet_cidr, 200)
  }
}

resource "openstack_networking_router_v2" "main" {
  name                = "${var.project_name}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "private" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.private.id
}
