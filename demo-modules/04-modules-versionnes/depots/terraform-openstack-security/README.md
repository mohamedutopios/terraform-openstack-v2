# terraform-openstack-security

Security group + règles ingress décrites par une liste d'objets.

## Utilisation

```hcl
module "security" {
  source = "git::https://gitlab.com/mohamed.aijjou1780/terraform-openstack-security.git?ref=v2.0.0"

  name = "dm4-sg"
  rules = [
    { protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "192.168.57.0/24" },
    { protocol = "icmp", remote_ip_prefix = "0.0.0.0/0" },
  ]
}
```

Passage de 1.x à 2.0.0 : voir la section « Migration » du
[CHANGELOG.md](CHANGELOG.md).

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
| [openstack_networking_secgroup_rule_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2) | resource |
| [openstack_networking_secgroup_v2.this](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Nom du security group | `string` | n/a | yes |
| rules | Règles ingress : protocole, plage de ports, CIDR source (obligatoire) | <pre>list(object({<br/>    protocol         = string<br/>    port_min         = optional(number)<br/>    port_max         = optional(number)<br/>    remote_ip_prefix = string<br/>  }))</pre> | n/a | yes |
| delete\_default\_rules | Supprimer les règles egress créées par défaut par Neutron | `bool` | `false` | no |
| description | Description du security group | `string` | `"Géré par Terraform"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| rule\_keys | Clés des règles créées (visualise le for\_each) |
| sg\_id | ID du security group créé |
| sg\_name | Nom du security group créé |
<!-- END_TF_DOCS -->
