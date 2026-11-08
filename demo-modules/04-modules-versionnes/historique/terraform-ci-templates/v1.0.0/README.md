# terraform-ci-templates

Pipelines GitLab CI partagés, **versionnés par tag** comme les modules :
un dépôt consommateur choisit sa version de pipeline avec `ref`.

| Fichier | Pour | Étapes |
|---|---|---|
| `templates/module.yml` | dépôts `terraform-openstack-*` | fmt, validate (TF 1.5 et 1.16), tflint, terraform-docs, terraform test, plan de l'exemple, Checkov (code + plan), KICS, puis sur tag : contrôle SemVer/CHANGELOG, Release, registre |
| `templates/infra.yml` | dépôts `infra-*` | refs de modules épinglées, gitleaks, fmt, validate, tflint, Checkov, KICS, plan + Checkov du plan, apply/destroy manuels |

```yaml
include:
  - project: mohamed.aijjou1780/terraform-ci-templates
    ref: v1.0.0
    file: templates/module.yml
```

Les versions des outils sont des variables (`TF_VERSION`, `CHECKOV_IMAGE`…)
surchargeables dans le dépôt consommateur.
