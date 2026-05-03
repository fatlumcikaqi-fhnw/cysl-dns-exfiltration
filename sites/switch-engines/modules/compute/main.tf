# Look up the OS image — must exist in Switch Engines image catalog
data "openstack_images_image_v2" "os" {
  name        = var.image_name
  most_recent = true
}

resource "openstack_compute_keypair_v2" "main" {
  name       = var.keypair_name
  public_key = var.ssh_public_key
}

resource "openstack_networking_port_v2" "vm" {
  for_each = var.instances

  name           = "port-${each.key}"
  network_id     = var.network_id
  admin_state_up = true

  fixed_ip {
    subnet_id  = var.subnet_id
    ip_address = each.value.fixed_ip != null ? each.value.fixed_ip : null
  }

  security_group_ids = [var.security_group_id]
}

resource "openstack_compute_instance_v2" "vm" {
  for_each = var.instances

  name        = each.key
  image_id    = data.openstack_images_image_v2.os.id
  flavor_name = each.value.flavor_name
  key_pair    = openstack_compute_keypair_v2.main.name
  user_data   = each.value.user_data != "" ? each.value.user_data : null

  network {
    port = openstack_networking_port_v2.vm[each.key].id
  }

  metadata = {
    managed_by = "opentofu"
    role       = each.key
  }
}

resource "openstack_networking_floatingip_v2" "fip" {
  for_each = { for name, cfg in var.instances : name => cfg if cfg.floating_ip }

  pool = var.floating_ip_pool
}

resource "openstack_networking_floatingip_associate_v2" "fip_assoc" {
  for_each = { for name, cfg in var.instances : name => cfg if cfg.floating_ip }

  floating_ip = openstack_networking_floatingip_v2.fip[each.key].address
  port_id     = openstack_networking_port_v2.vm[each.key].id
}
