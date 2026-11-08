# terraform-openstack-network

Réseau privé + sous-réseau + routeur raccordé au réseau externe.

## Utilisation

Toujours référencer un **tag** (jamais une branche) :

```hcl
module "network" {
  source = "git::https://gitlab.com/mohamed.aijjou1780/terraform-openstack-network.git?ref=v1.0.0"

  name                = "dm4"
  cidr                = "10.40.4.0/24"
  external_network_id = data.openstack_networking_network_v2.public.id
}
```

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
| [openstack_networking_network_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_network_v2) | resource |
| [openstack_networking_router_interface_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_router_interface_v2) | resource |
| [openstack_networking_router_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_router_v2) | resource |
| [openstack_networking_subnet_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_subnet_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| cidr | CIDR IPv4 du sous-réseau (ex. 10.40.4.0/24) | `string` | n/a | yes |
| external\_network\_id | ID du réseau externe (passerelle du routeur) | `string` | n/a | yes |
| name | Nom de base : réseau, sous-réseau et routeur en dérivent | `string` | n/a | yes |
| dns\_nameservers | DNS annoncés par le DHCP | `list(string)` | <pre>[<br/>  "8.8.8.8"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| network\_id | ID du réseau créé |
| router\_interface\_id | ID du raccordement routeur (permet d'ordonner la VM après lui) |
| subnet\_id | ID du sous-réseau créé |
<!-- END_TF_DOCS -->
