# terraform-ci-templates

Pipelines GitLab CI partagés, **versionnés par tag** comme les modules :
un dépôt consommateur choisit sa version de pipeline avec `ref`.

| Fichier | Pour | Étapes |
|---|---|---|
| `templates/module.yml` | dépôts `terraform-openstack-*` | fmt, validate (TF 1.5 et 1.16), tflint, terraform-docs, terraform test, plan de l'exemple, Checkov (code + plan), KICS, puis sur tag : contrôle SemVer/CHANGELOG, Release, registre |
| `templates/infra.yml` | dépôts `infra-*` | refs de modules épinglées, gitleaks, fmt, validate, tflint, Checkov, KICS, plan + Checkov du plan, apply/destroy manuels |
| `templates/environnements.yml` *(1.2.0)* | dépôts multi-environnements, une fois | refs, backends cohérents, matrice des versions, gitleaks, fmt, Checkov, KICS |
| `templates/environnement.yml` *(1.2.0)* | une fois **par environnement** (`inputs`) | validate, tflint, plan, Checkov du plan, apply/destroy manuels, dérive planifiée — seulement si `envs/<env>/` change |

```yaml
include:
  - project: mohamed.aijjou1780/terraform-ci-templates
    ref: v1.1.0
    file: templates/module.yml
```

Multi-environnements :

```yaml
include:
  - project: mohamed.aijjou1780/terraform-ci-templates
    ref: v1.2.0
    file: templates/environnements.yml
  - project: mohamed.aijjou1780/terraform-ci-templates
    ref: v1.2.0
    file: templates/environnement.yml
    inputs: { env: dev, tier: development }
```

Les versions des outils sont des variables (`TF_VERSION`, `CHECKOV_IMAGE`…)
surchargeables dans le dépôt consommateur.
