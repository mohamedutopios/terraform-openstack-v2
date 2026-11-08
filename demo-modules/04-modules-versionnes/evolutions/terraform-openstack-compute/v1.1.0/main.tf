# Module compute : keypair + N x (port + VM + IP flottante optionnelle)

locals {
  # 1 VM : nom inchangé par rapport à la 1.0.0 ; N VM : suffixe -1, -2...
  noms = [
    for i in range(var.instance_count) :
    var.instance_count == 1 ? var.name : "${var.name}-${i + 1}"
  ]
}

# Une seule keypair, partagée par toutes les VM
resource "openstack_compute_keypair_v2" "this" {
  name       = "${var.name}-key"
  public_key = var.public_key
}

resource "openstack_networking_port_v2" "this" {
  count = var.instance_count

  name               = "${local.noms[count.index]}-port"
  network_id         = var.network_id
  security_group_ids = var.security_group_ids

  fixed_ip {
    subnet_id = var.subnet_id
  }
}

resource "openstack_compute_instance_v2" "this" {
  count = var.instance_count

  name        = local.noms[count.index]
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = openstack_compute_keypair_v2.this.name
  user_data   = var.user_data

  network {
    port = openstack_networking_port_v2.this[count.index].id
  }
}

resource "openstack_networking_floatingip_v2" "this" {
  count = var.create_floating_ip ? var.instance_count : 0
  pool  = var.floating_pool
}

resource "openstack_networking_floatingip_associate_v2" "this" {
  count       = var.create_floating_ip ? var.instance_count : 0
  floating_ip = openstack_networking_floatingip_v2.this[count.index].address
  port_id     = openstack_networking_port_v2.this[count.index].id
}
