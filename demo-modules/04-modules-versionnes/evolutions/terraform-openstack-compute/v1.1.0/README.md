# terraform-openstack-compute

Keypair + une ou plusieurs VM (port + IP flottante optionnelle par VM).

## Utilisation

```hcl
module "vm" {
  source = "git::https://gitlab.com/mohamed.aijjou1780/terraform-openstack-compute.git?ref=v1.1.0"

  name               = "dm4-vm"
  instance_count     = 2
  image_name         = "cirros"
  flavor_name        = "m1.tiny"
  public_key         = file(pathexpand("~/.ssh/id_rsa.pub"))
  network_id         = module.network.network_id
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.security.sg_id]

  create_floating_ip = true
  floating_pool      = "public"
}

output "ssh" {
  value = [for ip in module.vm.floating_ips : "ssh cirros@${ip}"]
}
```

Avec `instance_count = 2`, les VM s'appellent `dm4-vm-1` et `dm4-vm-2`.
Avec `instance_count = 1` (défaut), la VM garde le nom `dm4-vm`.

## Passer de 1.0.0 à 1.1.0

Version **mineure** : changer `?ref=v1.0.0` en `?ref=v1.1.0` suffit, sans
autre modification. Le plan n'affiche alors que des déplacements
d'adresses (`has moved to ...[0]`), aucune ressource détruite.

Pour profiter de plusieurs VM :

| Avant (1.0.0) | Après (1.1.0) |
|---|---|
| — | `instance_count = 2` |
| `module.vm.private_ip` | `module.vm.private_ips` (liste) |
| `module.vm.floating_ip` | `module.vm.floating_ips` (liste) |
| `module.vm.instance_id` | `module.vm.instance_ids` (liste) |

Les sorties au singulier restent disponibles mais sont **dépréciées** : elles
disparaîtront en 2.0.0.

Avec `instance_count = 2` sur une infra existante, la VM `dm4-vm` est
**renommée** `dm4-vm-1` (modification sur place) et `dm4-vm-2` est créée.

Historique des versions : [CHANGELOG.md](CHANGELOG.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.5 |
| openstack | >= 2.1 |

## Providers

| Name | Version |
| ---- | ------- |
| openstack | >= 2.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [openstack_compute_instance_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_instance_v2) | resource |
| [openstack_compute_keypair_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_keypair_v2) | resource |
| [openstack_networking_floatingip_associate_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_associate_v2) | resource |
| [openstack_networking_floatingip_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_v2) | resource |
| [openstack_networking_port_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_port_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| flavor\_name | Flavor de la VM | `string` | n/a | yes |
| image\_name | Image Glance de la VM | `string` | n/a | yes |
| name | Nom de base : la VM, le port et la keypair en dérivent | `string` | n/a | yes |
| network\_id | Réseau où brancher la VM | `string` | n/a | yes |
| public\_key | Contenu de la clé publique SSH (pas le chemin) | `string` | n/a | yes |
| security\_group\_ids | Security groups appliqués au port | `list(string)` | n/a | yes |
| subnet\_id | Sous-réseau pour l'IP fixe | `string` | n/a | yes |
| create\_floating\_ip | Associer une IP flottante à la VM | `bool` | `false` | no |
| floating\_pool | Réseau externe fournissant l'IP flottante (requis si create\_floating\_ip) | `string` | `""` | no |
| user\_data | cloud-init optionnel | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| floating\_ip | IP flottante (null si non demandée) |
| instance\_id | ID de la VM |
| private\_ip | IP fixe de la VM |
<!-- END_TF_DOCS -->
