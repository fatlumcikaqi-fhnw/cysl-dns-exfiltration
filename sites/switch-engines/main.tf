locals {
  cloud_init = file("${path.module}/../../cloud-init/cloud-init.yml")

  instances_with_cloud_init = {
    for name, cfg in var.instances : name => merge(cfg, {
      user_data = cfg.user_data != "" ? cfg.user_data : local.cloud_init
    })
  }
}

module "network" {
  source = "./modules/network"

  project_name          = var.project_name
  external_network_name = var.external_network_name
  private_subnet_cidr   = var.private_subnet_cidr
}

module "security_groups" {
  source = "./modules/security_groups"

  project_name        = var.project_name
  private_subnet_cidr = var.private_subnet_cidr
}

module "compute" {
  source = "./modules/compute"

  instances         = local.instances_with_cloud_init
  image_name        = var.image_name
  keypair_name      = var.keypair_name
  ssh_public_key    = var.ssh_public_key
  network_id        = module.network.network_id
  subnet_id         = module.network.subnet_id
  security_group_id = module.security_groups.security_group_id
  floating_ip_pool  = var.floating_ip_pool

  depends_on = [module.network, module.security_groups]
}
