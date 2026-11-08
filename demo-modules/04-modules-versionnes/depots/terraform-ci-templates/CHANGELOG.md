# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) —
versions : [SemVer](https://semver.org/lang/fr/).

## [1.2.0] - 2026-11-10

### Ajouté

- `templates/environnements.yml` (inclus une fois) et
  `templates/environnement.yml` (inclus une fois par environnement, avec
  `inputs: env, tier, plan_en_mr`) pour les dépôts `envs/<env>/`.
- Contrôles `verifier-backends` (un état distinct par environnement, qui
  porte son nom) et `matrice-versions` (versions de modules par
  environnement).
- Jobs suffixés par environnement, déclenchés seulement si `envs/<env>/`
  change ; `derive-<env>` en pipeline planifié.

## [1.1.0] - 2026-11-06

### Ajouté

- `module.yml` : job `plan-exemple` (plan de `examples/basique` sans
  OpenStack) et job `checkov-plan` (Checkov sur le plan JSON, valeurs
  résolues). Un module qui passait en 1.0.0 peut échouer ici : c'est voulu.

## [1.0.0] - 2026-11-02

### Ajouté

- `templates/module.yml` et `templates/infra.yml`.
