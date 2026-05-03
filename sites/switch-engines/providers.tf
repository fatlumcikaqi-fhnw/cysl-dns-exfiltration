terraform {
  required_version = ">= 1.6.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.3.2"
    }
  }
}

provider "openstack" {
  region = var.region
}
