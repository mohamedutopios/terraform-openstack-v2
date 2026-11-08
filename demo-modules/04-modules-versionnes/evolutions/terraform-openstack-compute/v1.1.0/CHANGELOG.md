# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) —
versions : [SemVer](https://semver.org/lang/fr/).

## [1.1.0] - 2026-11-09

### Ajouté

- Variable `instance_count` (1 à 5, défaut `1`) : N VM identiques, une
  keypair partagée, un port et une IP flottante par VM.
- Sorties en liste : `instance_ids`, `private_ips`, `floating_ips`.
- Exemple `examples/plusieurs-vm`.

### Déprécié

- Sorties `instance_id`, `private_ip`, `floating_ip` : elles ne décrivent
  que la 1re VM. Toujours fournies en 1.x, **supprimées en 2.0.0**.

### Compatibilité

- Sans `instance_count`, rien ne change : mêmes ressources, mêmes noms.
- Blocs `moved` : la VM et le port existants deviennent `[0]` dans l'état,
  **sans destruction**.

## [1.0.0] - 2026-11-02

### Ajouté

- Keypair, port, VM, IP flottante optionnelle (`create_floating_ip`).
