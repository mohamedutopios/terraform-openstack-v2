# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) —
versions : [SemVer](https://semver.org/lang/fr/).

## [2.0.0] - 2026-11-08

### Modifié (CASSANT)

- `rules[].remote_ip_prefix` est désormais **obligatoire** (plus de défaut
  `0.0.0.0/0`).

### Ajouté

- Validations de `rules` : protocole (tcp/udp/icmp), CIDR valide, refus de
  SSH (tcp/22) ouvert à `0.0.0.0/0`.

### Migration depuis 1.x

Ajouter `remote_ip_prefix` à chaque règle :

```hcl
{ protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "192.168.57.0/24" },
{ protocol = "icmp", remote_ip_prefix = "0.0.0.0/0" },
```

Les clés des règles ne changent pas ; seules les règles dont le CIDR change
sont recréées.

## [1.1.0] - 2026-11-05

### Ajouté

- Variable `delete_default_rules` (défaut `false` : comportement inchangé).
- Sortie `sg_name`.

## [1.0.0] - 2026-11-02

### Ajouté

- Security group et règles ingress décrites par une liste d'objets.
