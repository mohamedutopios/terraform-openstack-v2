# Démo modules 4 — même composition que la démo 3, mais chaque module vient
# de SON dépôt git, à une version précise (tag SemVer).
#
#   ?ref=v1.0.0  -> git checkout du tag : reproductible, relu, testé
#   changer ref  -> terraform init (ou init -upgrade) pour re-télécharger

module "network" {
  source = "git::https://gitlab.com/mohamed.aijjou1780/terraform-openstack-network.git?ref=v1.0.0"

  name                = local.prefix
  cidr                = var.subnet_cidr
  dns_nameservers     = var.dns_nameservers
  external_network_id = data.openstack_networking_network_v2.public.id
}

module "security" {
  source = "git::https://gitlab.com/mohamed.aijjou1780/terraform-openstack-security.git?ref=v2.0.0"

  name        = "${local.prefix}-sg"
  description = "Demo modules 4 : SSH admin et ICMP"

  # v2.0.0 : remote_ip_prefix est obligatoire
  rules = [
    { protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = var.admin_cidr },
    { protocol = "icmp", remote_ip_prefix = "0.0.0.0/0" },
  ]
}

module "vm" {
  source = "git::https://gitlab.com/mohamed.aijjou1780/terraform-openstack-compute.git?ref=v1.1.0"

  name               = "${local.prefix}-vm"
  instance_count     = var.vm_count
  image_name         = var.image_name
  flavor_name        = var.flavor_name
  public_key         = file(pathexpand(var.public_key_path))
  network_id         = module.network.network_id
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.security.sg_id]

  create_floating_ip = true
  floating_pool      = var.external_network_name

  depends_on = [module.network]
}
