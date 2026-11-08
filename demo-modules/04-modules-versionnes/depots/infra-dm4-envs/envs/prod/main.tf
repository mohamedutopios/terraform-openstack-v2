# Composition identique dans chaque environnement ; seules changent :
#   - les VERSIONS des modules (?ref=) : promues de dev vers prod
#   - les VALEURS (terraform.tfvars)
# Une version n'est pas une variable (Terraform l'interdit) : elle est écrite
# ici, dans le dossier de l'environnement, et se lit dans la revue de code.

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
  description = "dm4 ${var.environnement} : SSH admin et ICMP"

  rules = [
    { protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = var.admin_cidr },
    { protocol = "icmp", remote_ip_prefix = "0.0.0.0/0" },
  ]
}

module "vm" {
  source = "git::https://gitlab.com/mohamed.aijjou1780/terraform-openstack-compute.git?ref=v1.0.0"

  name               = "${local.prefix}-vm"
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
