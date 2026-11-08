# Démo modules 4 — Modules dans des dépôts versionnés par tags, avec CI

Suite de `03-module-security` : les trois modules (`network`, `security`,
`compute`) quittent le dossier `modules/` de l'infra et deviennent **chacun
un dépôt git**, publié par **tags SemVer** (`v1.0.0`, `v1.1.0`, `v2.0.0`).
L'infra ne contient plus que la composition et **choisit la version** de
chaque module. Deux familles de pipelines GitLab CI encadrent le tout :

- **pipeline module** : qualité, tests, sécurité, puis release sur tag ;
- **pipeline infra** : conformité des références, sécurité, plan, apply manuel.

Les pipelines sont eux-mêmes dans un dépôt partagé, **versionné par tag**.

Schémas des démos (vue globale, avant / après, pipelines, promotion) :
[schemas-demos.html](schemas-demos.html), généré par `python3 outils/generer-schemas.py`.

## Architecture : 5 dépôts (+ `infra-dm4-envs`, voir DEMO-ENVIRONNEMENTS.md)

```
 terraform-ci-templates  (v1.0.0, v1.1.0)          pipelines partagés
   ├─ templates/module.yml  ──include ref: v1.1.0──┐
   └─ templates/infra.yml   ──include ref: v1.1.0──┼──────────────┐
                                                   │              │
 terraform-openstack-network   (v1.0.0)  ──────────┤              │
 terraform-openstack-security  (v1.0.0, v1.1.0, v2.0.0) ──────────┤
 terraform-openstack-compute   (v1.0.0)  ──────────┘              │
        ▲            ▲            ▲                               │
        │ ?ref=v1.0.0│ ?ref=v2.0.0│ ?ref=v1.0.0                   │
        └────────────┴────────────┴──────  infra-dm4  ◄───────────┘
                                          (composition, état GitLab)
```

## Structure du dossier

```
04-modules-versionnes/
├── depots/                         <- un sous-dossier = un dépôt (version courante)
│   ├── terraform-ci-templates/     templates/module.yml, templates/infra.yml
│   ├── terraform-openstack-network/
│   ├── terraform-openstack-security/
│   ├── terraform-openstack-compute/
│   │     main.tf variables.tf outputs.tf versions.tf
│   │     examples/basique/   exemple = doc exécutable + cible des scanners
│   │     tests/*.tftest.hcl  tests unitaires, provider simulé
│   │     CHANGELOG.md  README.md (section générée par terraform-docs)
│   │     .gitlab-ci.yml  .tflint.hcl  .checkov.yaml  .terraform-docs.yml
│   │     .pre-commit-config.yaml
│   ├── infra-dm4/                  main.tf (sources git::...?ref=vX.Y.Z)
│         .terraform.lock.hcl  .gitlab-ci.yml  .tflint.hcl  .checkov.yaml
│         renovate.json  clouds.yaml.example
│   └── infra-dm4-envs/             envs/dev|staging|prod (un backend.hcl et un état chacun), socle/
├── schemas-demos.html              schémas des démos (généré par outils/generer-schemas.py)
├── historique/                     fichiers qui différaient aux anciens tags
├── evolutions/                     versions cibles de DEMO-NOUVELLE-VERSION.md
├── scripts/
│   ├── creer-depots-locaux.sh      fabrique les dépôts git + tags dans .depots-git/
│   ├── env-depots-locaux.sh        redirige gitlab.com -> .depots-git/ (terminal courant)
│   ├── controles-locaux.sh         rejoue les jobs CI avec Docker (mêmes images)
│   ├── generer-doc.sh              terraform-docs, même version que la CI
│   ├── demo-nouvelle-version.sh    déroulé automatique de DEMO-NOUVELLE-VERSION.md
│   ├── demo-environnements.sh      déroulé automatique de DEMO-ENVIRONNEMENTS.md
│   ├── promouvoir.sh               change le ?ref= d'un module dans UN environnement
│   ├── publier-compute-v1.1.0.sh   publie compute v1.1.0 d'un coup
│   └── publier-sur-gitlab.sh       crée et configure les 5 projets GitLab
├── .depots-git/                    (généré, ignoré par git) le « serveur git » local
└── travail/                        (généré, ignoré par git) clones de travail
```

## L'histoire des versions

| Dépôt | Tag / commit | Contenu | Type SemVer |
|---|---|---|---|
| ci-templates | `v1.0.0` | pipelines module + infra, contrôles statiques | — |
| ci-templates | `v1.1.0` | + `plan-exemple` et `checkov-plan` dans `module.yml` | mineure |
| ci-templates | `v1.2.0` | + `environnements.yml` et `environnement.yml` (multi-environnements, `inputs`) | mineure |
| security | `v1.0.0` | module de la démo 3 : `remote_ip_prefix` optionnel, défaut `0.0.0.0/0` | — |
| security | `v1.1.0` | + `delete_default_rules` (avec défaut), + sortie `sg_name` | **mineure** : rien ne casse |
| security | *commit* | passage au pipeline `v1.1.0` → **rouge** : Checkov voit SSH ouvert au monde | — |
| security | `v2.0.0` | `remote_ip_prefix` **obligatoire** + validations (CIDR, SSH ≠ 0.0.0.0/0) | **majeure** : les appelants doivent changer |
| network, compute | `v1.0.0` puis *commit* | passage au pipeline `v1.1.0` → vert | — |

Règle SemVer appliquée à un module :
- **correctif** : comportement corrigé, interface identique ;
- **mineure** : ajout rétrocompatible (variable **avec défaut**, nouvelle sortie) ;
- **majeure** : variable supprimée/renommée/rendue obligatoire, type changé,
  ressource renommée sans `moved` → les consommateurs doivent adapter leur code.

## Les pipelines

### Pipeline module (`templates/module.yml`) — runners partagés, aucun cloud

| Stage | Job | Outil | Ce qu'il garantit |
|---|---|---|---|
| qualite | `fmt` | `terraform fmt -check` | style homogène |
| qualite | `validate` ×2 | Terraform **1.5.7 et 1.16.7** (matrice) | `required_version >= 1.5` est vrai |
| qualite | `tflint` | TFLint, preset `all` | structure standard, variables typées et documentées, snake_case |
| qualite | `docs` | `terraform-docs --output-check` | README synchronisé avec les variables |
| test | `terraform-test` | `terraform test` + `mock_provider` | logique du module (count, for_each, validations) |
| test | `plan-exemple` *(v1.1.0)* | `terraform plan` de `examples/basique` | plan JSON aux valeurs **résolues** |
| securite | `checkov` | Checkov, analyse du code | règles `CKV_OPENSTACK_*` |
| securite | `checkov-plan` *(v1.1.0)* | Checkov sur le plan JSON | ce que l'analyse statique ne voit pas |
| securite | `kics` | KICS, rapport SAST GitLab | second moteur (Rego) |
| release | `verifier-tag` | shell | tag `vX.Y.Z` **et** section `## [X.Y.Z]` dans le CHANGELOG |
| release | `release` | release-cli | Release GitLab, notes = section du CHANGELOG |
| release | `publier-registre` | API GitLab | module aussi dans le registre Terraform du projet |

Le plan de l'exemple tourne **sans OpenStack** : le provider n'authentifie
qu'au premier appel d'API, et un plan de pure création n'en fait aucun
(identifiants factices `OS_*` dans le job).

### Pipeline infra (`templates/infra.yml`)

| Stage | Job | Ce qu'il garantit |
|---|---|---|
| conformite | `verifier-refs-modules` | chaque module est `git::...?ref=vX.Y.Z` (pas de `./modules`, pas de branche) |
| conformite | `gitleaks` | aucun secret commité (ex. `clouds.yaml` avec mot de passe) |
| qualite | `fmt`, `validate` | `init -lockfile=readonly` : providers du `.terraform.lock.hcl` uniquement |
| qualite | `tflint --call-module-type=all` | évalue aussi les appels de modules |
| securite | `checkov` | code de l'infra **et** des modules téléchargés ; `CKV_TF_2` = ref SemVer |
| securite | `kics` | rapport SAST |
| plan | `plan` *(runner `openstack`)* | plan sur l'état GitLab, résumé dans la MR |
| plan | `checkov-plan` | sécurité sur les valeurs réelles |
| deploiement | `apply` / `destroy` | **manuels**, branche par défaut, applique le plan relu |

`CKV_TF_1` (exiger un hash de commit) est désactivé dans `.checkov.yaml`
avec sa justification : un tag est **déplaçable** par défaut, un hash ne
l'est pas. Le choix « tag lisible » n'est sûr qu'avec des **tags protégés**
(`v*`, créés par les maintainers, jamais déplacés), ce que configure
`publier-sur-gitlab.sh`.

## Démos suivantes

| Démo | Sujet |
|---|---|
| [DEMO-NOUVELLE-VERSION.md](DEMO-NOUVELLE-VERSION.md) | modifier un module, le valider, le taguer ; l'infra lit la doc et adopte la version |
| [DEMO-ENVIRONNEMENTS.md](DEMO-ENVIRONNEMENTS.md) | dev / staging / prod : un dossier, un backend, un état, des identifiants par environnement ; promotion des versions |

## Démo : publier et adopter une nouvelle version

[DEMO-NOUVELLE-VERSION.md](DEMO-NOUVELLE-VERSION.md) : le module compute
évolue en `v1.1.0` (plusieurs VM), passe sa pipeline, est tagué et
documenté ; l'infra lit la doc, monte la version, s'ajuste et rejoue sa
pipeline. Déroulé automatique : `PAUSE=1 ./scripts/demo-nouvelle-version.sh`.

## Déroulé — en local, sans GitLab

Prérequis : Terraform ≥ 1.5, git ≥ 2.31, Docker (pour `controles-locaux.sh`).

### 1. Fabriquer les dépôts et leurs tags

```bash
cd demo-modules/04-modules-versionnes
./scripts/creer-depots-locaux.sh
```

```bash
git -C .depots-git/terraform-openstack-security.git log --oneline --decorate
```

```bash
git -C .depots-git/terraform-openstack-security.git diff v1.1.0 v2.0.0 -- variables.tf
```

### 2. Consommer les modules par tag

```bash
eval "$(./scripts/env-depots-locaux.sh)"
cd depots/infra-dm4
terraform init -backend=false
```

`terraform init` affiche `Downloading git::https://gitlab.com/...?ref=v2.0.0` :
l'URL du code est la vraie, c'est git qui la redirige vers `.depots-git/`
(`url.<base>.insteadOf`, mêmes mécanismes qu'en CI pour injecter le jeton).

```bash
git -C .terraform/modules/security describe --tags
```

### 3. Pipeline module : ce que voit chaque outil

```bash
cd ../..
./scripts/controles-locaux.sh .depots-git/terraform-openstack-security.git v1.0.0
```

Bilan attendu : tout vert **sauf `checkov-plan`** :
`CKV_OPENSTACK_2 ... FAILED for resource: module.security.openstack_networking_secgroup_rule_v2.this["tcp-22-22"]`.
Le `checkov` statique, lui, passe : il ne résout pas le `for_each` sur une
liste d'objets ni le défaut `optional(string, "0.0.0.0/0")`. Le plan JSON
contient les valeurs finales : la règle SSH ouverte au monde y apparaît.

```bash
./scripts/controles-locaux.sh depots/terraform-openstack-security
```

Version `v2.0.0` : tout vert, dont les 3 tests `terraform test`
(`refuse_ssh_ouvert_au_monde` vérifie que la validation bloque le cas).

### 4. Montée de version mineure puis majeure dans l'infra

Partir de l'appel tel qu'il était avec la v1.1.0 (dans `depots/infra-dm4/main.tf`) :

```hcl
module "security" {
  source = "git::https://gitlab.com/mohamed.aijjou1780/terraform-openstack-security.git?ref=v1.1.0"

  name        = "${local.prefix}-sg"
  description = "Demo modules 4 : SSH admin et ICMP"
  rules = [
    { protocol = "tcp", port_min = 22, port_max = 22 },
    { protocol = "icmp" },
  ]
}
```

`terraform init -backend=false && terraform validate` : valide. Passer `ref`
à `v2.0.0` sans autre changement :

```text
Error: Invalid value for input variable
  ... element 0: attribute "remote_ip_prefix" is required.
```

La majeure casse **au validate**, avant tout déploiement. La migration est
décrite dans le `CHANGELOG.md` du module ; une fois appliquée (version
actuelle du fichier, avec `var.admin_cidr`), tout repasse au vert.

Changer `ref` suffit à `terraform init` pour re-télécharger le module
(`-upgrade` ne sert qu'aux contraintes de version du registre).

### 5. Pipeline infra : les garde-fous

```bash
./scripts/controles-locaux.sh depots/infra-dm4
```

Puis, sur une copie de l'infra, provoquer les échecs :

| Modification | Jobs en échec |
|---|---|
| `?ref=v2.0.0` → `?ref=main` | `verifier-refs-modules`, `checkov` (`CKV_TF_2`) |
| `source = "./modules/security"` | `verifier-refs-modules` |
| copier un vrai `clouds.yaml` dans le dépôt | `gitleaks` (`generic-api-key`) |
| règle SSH avec `remote_ip_prefix = "0.0.0.0/0"` | `validate` (validation du module v2) |

### 6. Déployer sur l'OpenStack du lab

```bash
cd depots/infra-dm4
cp clouds.yaml.example clouds.yaml     # renseigner le mot de passe
terraform init
terraform apply
```

Sans `backend_ci.tf`, l'état est local en poste de travail ; en CI il est
stocké par GitLab (Operate → Terraform states → `dm4`).

## Déroulé — sur GitLab

### Publication

```bash
export GITLAB_TOKEN="<jeton personnel, scope api>"
CLOUDS_YAML=depots/infra-dm4/clouds.yaml CLE_PUBLIQUE=~/.ssh/id_rsa.pub ./scripts/publier-sur-gitlab.sh
```

`SIMULATION=1 ./scripts/publier-sur-gitlab.sh` affiche les actions sans rien
appeler. Le script crée les 5 projets privés, protège les tags `v*`, ajoute
`infra-dm4` à l'allowlist du jeton CI de chaque module, crée les variables
de type fichier `OS_CLIENT_CONFIG_FILE` et `TF_VAR_public_key_path`, puis
pousse l'historique **commit par commit** : un pipeline par étape.

Pipelines obtenus dans `terraform-openstack-security` :

| Ref | Template | Résultat |
|---|---|---|
| tag `v1.0.0`, tag `v1.1.0` | `v1.0.0` | vert + Release + paquet dans le registre |
| `main` (commit « ci: passage... ») | `v1.1.0` | **rouge** : `checkov-plan` |
| tag `v2.0.0` | `v1.1.0` | vert + Release (notes = section 2.0.0 du CHANGELOG) |

### Runner pour plan / apply

L'API OpenStack du lab (`192.168.56.250`) n'est pas joignable depuis les
runners partagés de gitlab.com. Les jobs `plan`, `apply`, `destroy` portent
le tag `openstack` : enregistrer un runner sur une machine qui joint l'API
(l'hôte VirtualBox) — projet `infra-dm4` → Settings → CI/CD → Runners →
*New project runner*, tag `openstack`, puis :

```bash
gitlab-runner register --url https://gitlab.com --token <glrt-...> --executor docker --docker-image alpine:3.22
```

### Mises à jour de modules automatiques (optionnel)

`infra-dm4/renovate.json` : Renovate détecte les nouveaux tags des sources
`git::...?ref=` et ouvre une MR par montée de version ; les majeures sont
étiquetées `breaking-change`. Le pipeline infra de la MR montre alors
immédiatement si la nouvelle version casse quelque chose.

### Consommer depuis le registre plutôt que par git

Le job `publier-registre` rend aussi chaque version disponible dans le
registre Terraform de GitLab :

```hcl
module "security" {
  source  = "gitlab.com/mohamed.aijjou1780/security/openstack"
  version = "~> 2.0"
}
```

Le registre permet les contraintes (`~>`), git impose une version exacte.
Il demande en contrepartie `terraform login gitlab.com` (ou un jeton dans
`TF_TOKEN_gitlab_com`).

## Points d'attention

- **Un tag n'est immuable que s'il est protégé.** Sans protection,
  `git tag -f v2.0.0 && git push -f --tags` change le code derrière la même
  référence. Alternative stricte : `?ref=<hash de commit>` (`CKV_TF_1`).
- **Le module fixe un minimum, l'infra épingle.** Modules :
  `version = ">= 2.1"` ; infra : `~> 2.1` + `.terraform.lock.hcl` commité.
- **`terraform.tfvars` est prioritaire sur `TF_VAR_*`.** D'où
  `public_key_path` en valeur par défaut de la variable, et non dans le
  tfvars : la variable CI peut ainsi la remplacer.
- **Clé de `for_each` stable entre versions.** La v2.0.0 garde les clés
  `tcp-22-22`, `icmp-0-0` : la montée ne recrée que les règles dont le CIDR
  change.
- **terraform-docs** n'est plus publié qu'en images par architecture
  depuis la 0.21 (`0.24.0-amd64`, `0.24.0-arm64`).
- **KICS** n'a pas de requêtes OpenStack ; il apporte surtout des règles
  génériques Terraform (nommage, module git sans révision…). Checkov porte
  les règles `CKV_OPENSTACK_*`.
- **Salle sans Internet** : `terraform providers mirror <dossier>` sur un
  poste connecté, puis `MIROIR_PROVIDERS=<dossier> ./scripts/controles-locaux.sh ...`.
