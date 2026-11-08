# Démo modules 2 — le réseau rejoint le compute en module.
# Il ne reste que le security group dans le root : voyez comme la sortie
# d'un module (network_id, subnet_id) alimente l'entrée d'un autre.

# --- Le socle réseau : un appel de module ---
module "network" {
  source = "./modules/network"

  name                = local.prefix
  cidr                = var.subnet_cidr
  dns_nameservers     = var.dns_nameservers
  external_network_id = data.openstack_networking_network_v2.public.id
}

# --- Security group (encore inline — modularisé en démo 3) ---
resource "openstack_networking_secgroup_v2" "sg" {
  name        = local.sg_name
  description = "Demo modules 2 : SSH et ICMP"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg.id
}

# --- La VM : les IDs viennent du module network ---
module "vm" {
  source = "./modules/compute"

  name               = local.vm_name
  image_name         = var.image_name
  flavor_name        = var.flavor_name
  public_key         = file(pathexpand(var.public_key_path))
  network_id         = module.network.network_id
  subnet_id          = module.network.subnet_id
  security_group_ids = [openstack_networking_secgroup_v2.sg.id]

  create_floating_ip = true
  floating_pool      = var.external_network_name

  depends_on = [module.network]
}
