# Démo — Publier une nouvelle version d'un module, puis l'adopter dans l'infra

Le cycle complet d'une évolution de module, de la modification au plan de
l'infra :

```
 module compute                                   infra-dm4
 ──────────────                                   ─────────
 1. branche feat/instance-count
 2. modification + doc rédigée
 3. pipeline ............ ROUGE (doc périmée)
 4. terraform-docs
 5. pipeline ............ VERT
 6. merge + tag v1.1.0
 7. pipeline du tag ..... VERT + Release ──────►  8. lire la doc de v1.1.0
                                                  9. ?ref=v1.1.0 seul ...... VERT (mineure)
                                                 10. ajustement selon la doc
                                                 11. pipeline ............. VERT
                                                 12. merge -> plan : 0 destruction
```

**L'évolution** : `terraform-openstack-compute` passe de `v1.0.0` à `v1.1.0`
et sait déployer **plusieurs VM** (`instance_count`). Version **mineure** :

- la nouvelle variable a un défaut (`1`) qui garde le comportement 1.0.0 ;
- les anciennes sorties (`private_ip`, `floating_ip`, `instance_id`) restent,
  marquées dépréciées ; de nouvelles sorties en liste s'ajoutent ;
- des blocs `moved` font passer la VM et le port existants à l'adresse
  `[0]` **sans les détruire**.

Les fichiers cibles sont dans `evolutions/` :

| Dossier | Contenu |
|---|---|
| `evolutions/terraform-openstack-compute/v1.1.0/` | `main.tf`, `moved.tf`, `variables.tf`, `outputs.tf`, tests, exemple `plusieurs-vm`, `CHANGELOG.md`, `README.md` (partie rédigée à jour, partie générée **pas encore** régénérée) |
| `evolutions/infra-dm4/compute-v1.1.0/` | `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars` de l'infra ajustée |

Déroulé automatique de toutes les étapes ci-dessous :

```bash
PAUSE=1 ./scripts/demo-nouvelle-version.sh
```

## Préparation

```bash
cd demo-modules/04-modules-versionnes
./scripts/creer-depots-locaux.sh
eval "$(./scripts/env-depots-locaux.sh)"
mkdir -p travail
```

`creer-depots-locaux.sh` remet tous les dépôts à leur état initial (compute
en `v1.0.0`) : la démo est rejouable.

## Partie 1 — Le module : modifier, documenter, valider, taguer

### 1. Branche de travail

```bash
git clone https://gitlab.com/mohamed.aijjou1780/terraform-openstack-compute.git travail/terraform-openstack-compute
cd travail/terraform-openstack-compute
git switch -c feat/instance-count
```

### 2. La modification

Copier la version cible (ou la saisir) :

```bash
rsync -a ../../evolutions/terraform-openstack-compute/v1.1.0/ ./
git status --short
```

Les points à montrer :

`variables.tf` — nouvelle entrée **avec défaut** et validation :

```hcl
variable "instance_count" {
  description = "Nombre de VM identiques (1 à 5). À 1, les noms sont ceux de la 1.0.0 ; au-delà, suffixe -1, -2..."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 5 && floor(var.instance_count) == var.instance_count
    error_message = "instance_count doit être un entier entre 1 et 5."
  }
}
```

`main.tf` — port, VM et IP flottante passent sous `count` ; la keypair reste
unique.

`moved.tf` — ce qui rend le changement **non cassant** :

```hcl
moved {
  from = openstack_compute_instance_v2.this
  to   = openstack_compute_instance_v2.this[0]
}
```

`outputs.tf` — `instance_ids`, `private_ips`, `floating_ips` ajoutées ;
`instance_id`, `private_ip`, `floating_ip` conservées, description
« DÉPRÉCIÉE (suppression en 2.0.0) ».

`tests/compute.tftest.hcl` — 3 nouveaux tests : nom inchangé avec 1 VM,
noms `-1 -2 -3` avec 3 VM, refus de `instance_count = 6`.

`CHANGELOG.md` — section `## [1.1.0]` : Ajouté / Déprécié / Compatibilité.

`README.md` — la partie **rédigée** : exemple d'utilisation à jour et
section « Passer de 1.0.0 à 1.1.0 » (tableau avant/après). C'est elle que
lira l'équipe infra.

### 3. Pipeline de la branche : rouge

```bash
cd ../..
./scripts/controles-locaux.sh travail/terraform-openstack-compute
```

```text
  OK    tflint
  ECHEC docs            Error: README.md is out of date
  OK    terraform-test
```

La partie **générée** du README (tableaux Inputs / Outputs) décrit encore
la 1.0.0 : `instance_count` et les sorties en liste n'y figurent pas. Le
job `docs` empêche de publier une doc fausse.

### 4. Régénérer la documentation depuis le code

```bash
./scripts/generer-doc.sh travail/terraform-openstack-compute
git -C travail/terraform-openstack-compute diff README.md
```

Le diff montre `instance_count` dans **Inputs**, les trois sorties en liste
dans **Outputs**, `[0]` sur les ressources. Le script utilise la même image
terraform-docs (0.24) que la CI : une autre version produirait un format
différent et le job resterait rouge.

### 5. Pipeline de la branche : vert

```bash
./scripts/controles-locaux.sh travail/terraform-openstack-compute
```

Tous les jobs passent, dont `validate` en Terraform 1.5.7 et 1.16.7, les 5
tests, `plan-exemple` et `checkov-plan`.

### 6. Merge et tag

```bash
cd travail/terraform-openstack-compute
git add -A
git commit -m "feat: instance_count pour déployer plusieurs VM"
git switch main
git merge --no-ff feat/instance-count
git tag -a v1.1.0 -m "terraform-openstack-compute v1.1.0"
git push origin main v1.1.0
cd ../..
```

Choix du numéro : nouvelle fonctionnalité, rien ne casse pour les
consommateurs existants → **mineure** (`1.0.0` → `1.1.0`).

### 7. Pipeline du tag

```bash
./scripts/controles-locaux.sh .depots-git/terraform-openstack-compute.git v1.1.0
```

En plus des contrôles, `verifier-tag` vérifie le format `vX.Y.Z` et la
présence de `## [1.1.0]` dans le CHANGELOG, puis extrait les **notes de
version** (sur GitLab : texte de la Release).

## Partie 2 — L'infra : lire la doc, monter la version, s'ajuster

### 8. Branche et lecture de la doc

```bash
git clone https://gitlab.com/mohamed.aijjou1780/infra-dm4.git travail/infra-dm4
cd travail/infra-dm4
git switch -c chore/compute-v1.1.0
```

La doc de la nouvelle version, au tag exact :

```bash
git -C ../../.depots-git/terraform-openstack-compute.git show v1.1.0:README.md
```

```bash
git -C ../../.depots-git/terraform-openstack-compute.git show v1.1.0:CHANGELOG.md
```

Sur GitLab : README du projet affiché au tag `v1.1.0`, ou page de la
Release. Après `terraform init`, la doc est aussi dans
`.terraform/modules/vm/README.md` : elle voyage avec le code.

Ce qu'en retient l'infra :

- mineure → changer `ref` suffit, sans autre modification ;
- pour 2 VM : `instance_count`, et passer aux sorties en liste ;
- `dm4-vm` sera renommée `dm4-vm-1` (sur place), `dm4-vm-2` créée.

### 9. Premier temps : seulement la version

Dans `main.tf` :

```hcl
  source = "git::https://gitlab.com/mohamed.aijjou1780/terraform-openstack-compute.git?ref=v1.1.0"
```

```bash
cd ../..
./scripts/controles-locaux.sh travail/infra-dm4
```

Pipeline **vert** sans toucher au reste : la promesse d'une mineure est
tenue (les sorties dépréciées `private_ip`, `floating_ip` fonctionnent
encore).

### 10. Deuxième temps : s'ajuster d'après la doc

```bash
rsync -a evolutions/infra-dm4/compute-v1.1.0/ travail/infra-dm4/
git -C travail/infra-dm4 diff
```

| Fichier | Changement |
|---|---|
| `main.tf` | `instance_count = var.vm_count` dans le module `vm` |
| `variables.tf` | nouvelle variable `vm_count` (défaut `1`) |
| `terraform.tfvars` | `vm_count = 2` |
| `outputs.tf` | `ips_privees = module.vm.private_ips`, `ips_flottantes = module.vm.floating_ips`, `ssh` devient une liste |

### 11. Pipeline de l'infra avec la nouvelle version

```bash
./scripts/controles-locaux.sh travail/infra-dm4
```

| Job | Ce qu'il vérifie sur cette montée de version |
|---|---|
| `verifier-refs-modules` | `?ref=v1.1.0` est bien un tag SemVer |
| `gitleaks` | pas de secret ajouté |
| `validate` | télécharge compute **v1.1.0**, contrôle `instance_count` et les nouvelles sorties |
| `tflint --call-module-type=all` | évalue l'appel du module avec ses nouvelles entrées |
| `checkov` | analyse aussi le code de compute v1.1.0 téléchargé |
| `kics` | analyse de l'infra |
| `plan` + `checkov-plan` *(GitLab, runner `openstack`)* | plan réel et sécurité sur les valeurs résolues |

Ce que le pipeline aurait arrêté :

| Erreur | Job rouge | Message |
|---|---|---|
| `instance_count = 2` avec encore `?ref=v1.0.0` | `validate` (dès `init`) | `Unsupported argument` — `An argument named "instance_count" is not expected here.` |
| `vm_count = 6` dans `terraform.tfvars` | `plan` | `instance_count doit être un entier entre 1 et 5.` (`validate` ne lit pas les tfvars : c'est le plan qui évalue la validation du module) |
| `?ref=main` pour aller plus vite | `verifier-refs-modules`, `checkov` (`CKV_TF_2`) | module non épinglé |
| doc du module non régénérée avant le tag | pipeline du module (`docs`) | le tag n'aurait pas eu de Release |

### 12. Merge, puis plan sur le lab

```bash
cd travail/infra-dm4
git add -A
git commit -m "chore: module compute v1.1.0, 2 VM"
git switch main
git merge --no-ff chore/compute-v1.1.0
git push origin main
```

Sur l'OpenStack du lab, à partir d'une infra déjà déployée en compute
`v1.0.0` :

```bash
cp ../../depots/infra-dm4/clouds.yaml.example clouds.yaml   # mot de passe
terraform init
terraform plan
```

```text
  # module.vm.openstack_compute_instance_v2.this[0] will be updated in-place
  # (moved from module.vm.openstack_compute_instance_v2.this)
      ~ name = "dm4-vm" -> "dm4-vm-1"
  # module.vm.openstack_networking_port_v2.this[0] will be updated in-place
  # (moved from module.vm.openstack_networking_port_v2.this)
      ~ name = "dm4-vm-port" -> "dm4-vm-1-port"
  # module.vm.openstack_compute_instance_v2.this[1] will be created
  ...
Plan: 4 to add, 2 to change, 0 to destroy.
```

**0 to destroy** : grâce aux blocs `moved`, la VM existante est conservée.
Sans `moved.tf` dans le module, la même montée de version aurait détruit
puis recréé `dm4-vm`.

## Sur GitLab

Mêmes étapes, avec les vrais pipelines (dépôts publiés par
`publier-sur-gitlab.sh`) :

| Étape locale | Sur GitLab |
|---|---|
| 1–5 | `git push -u origin feat/instance-count`, ouvrir une MR : pipeline rouge (`docs`), puis vert après `terraform-docs` |
| 6 | merger la MR, puis taguer `main` : `git tag -a v1.1.0 ... && git push origin v1.1.0` (tag protégé : rôle maintainer) |
| 7 | pipeline du tag : Release `compute v1.1.0` (notes = CHANGELOG), paquet `compute/openstack/1.1.0` dans le registre |
| 8 | README au tag `v1.1.0`, page Releases ; avec Renovate, la MR de montée de version est ouverte automatiquement |
| 9–11 | MR sur `infra-dm4` : pipeline de MR, widget Terraform « 4 to add, 2 to change, 0 to delete » |
| 12 | merge, puis job `apply` manuel : il applique exactement le plan relu |
