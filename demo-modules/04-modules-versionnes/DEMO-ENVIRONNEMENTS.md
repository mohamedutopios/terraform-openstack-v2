# Démo — Déployer l'infra en dev, staging et prod (un état par environnement)

Même infrastructure que `infra-dm4`, déployée dans **trois environnements
isolés**, depuis un seul dépôt : `infra-dm4-envs`. Chaque environnement a
**son dossier, son backend, son état, ses identifiants, ses versions de
modules**. Les modules versionnés se **promeuvent** de dev vers prod.

## La bonne pratique, en 7 règles

| # | Règle | Ce que ça évite | Où c'est dans la démo |
|---|---|---|---|
| 1 | **Un dossier = un root = un état** par environnement | un `destroy` en dev qui touche la prod ; un `apply` avec le mauvais tfvars | `envs/dev`, `envs/staging`, `envs/prod` |
| 2 | **Backend explicite et versionné** par environnement, état nommé d'après l'environnement | écrire dans l'état d'un autre environnement | `envs/<env>/backend.tf` + `backend.hcl`, job `verifier-backends` |
| 3 | **Code identique, valeurs différentes** : les écarts vivent dans `terraform.tfvars` | des environnements qui divergent sans qu'on le voie | `diff -r envs/dev envs/prod` |
| 4 | **Versions de modules épinglées par environnement** et **promues** dev → staging → prod, un commit par environnement | une nouvelle version qui part en prod sans être passée en dev | `?ref=` par environnement, `promouvoir.sh`, job `matrice-versions` |
| 5 | **Identifiants séparés** : un projet OpenStack et un compte par environnement ; en CI, une variable par environnement, **protégée** pour prod | la CI de dev qui peut modifier la prod | `socle/`, variables GitLab à portée d'environnement |
| 6 | **Pipeline par environnement** : seul l'environnement modifié est planifié ; `apply` manuel, sur la branche par défaut, du plan relu | un changement de dev qui replanifie la prod ; un apply non relu | `templates/environnement.yml` inclus 3 fois |
| 7 | **Détection de dérive** planifiée | une modification manuelle (Horizon) invisible | jobs `derive-<env>` |

### Pourquoi pas les autres approches ?

| Approche | Isolation des états | Limite |
|---|---|---|
| Workspaces (`terraform workspace select prod`) | un état par workspace, **même backend, mêmes identifiants** | l'environnement courant est invisible dans le code ; une erreur de `select` suffit |
| Un dossier + `-backend-config` + `-var-file` (cf. `demo-backend-gitlab`) | oui | rien n'empêche d'associer le backend de prod au tfvars de dev |
| Dossier par env + composition locale `../../stack` (cf. `demo-environnements`) | oui | une modification de `stack/` part dans **tous** les environnements au prochain apply : pas de promotion |
| **Dossier par env + modules versionnés** (ici) | oui | la composition est répétée dans chaque `main.tf` (≈ 40 lignes) : la matrice des versions et la revue de code la surveillent |

## Structure du dépôt `infra-dm4-envs`

```
infra-dm4-envs/
├── .gitlab-ci.yml          include commun + environnement.yml ×3 (inputs)
├── .tflint.hcl  .checkov.yaml  .gitignore  clouds.yaml.example
├── envs/
│   ├── dev/
│   │   ├── backend.tf      backend "http" {}   (partiel, sans secret)
│   │   ├── backend.hcl     adresse de l'état GitLab "dm4-dev"
│   │   ├── main.tf         network / security / compute, ?ref= de CET env
│   │   ├── terraform.tfvars  environnement = "dev", CIDR, flavor, SSH...
│   │   ├── variables.tf  outputs.tf  locals.tf  data.tf
│   │   ├── provider.tf     cloud = "dm4-dev"
│   │   ├── versions.tf  .terraform.lock.hcl
│   ├── staging/            mêmes fichiers, état "dm4-staging"
│   └── prod/               mêmes fichiers, état "dm4-prod"
└── socle/                  projets, comptes et quotas par env (admin, une fois)
```

Ce qui distingue les environnements (`terraform.tfvars`) :

| | dev | staging | prod |
|---|---|---|---|
| État GitLab | `dm4-dev` | `dm4-staging` | `dm4-prod` |
| Entrée clouds.yaml / projet | `dm4-dev` | `dm4-staging` | `dm4-prod` |
| Préfixe des ressources | `dm4-dev-` | `dm4-staging-` | `dm4-prod-` |
| Sous-réseau | `10.60.1.0/24` | `10.60.2.0/24` | `10.60.3.0/24` |
| SSH autorisé depuis | `192.168.57.0/24` | `192.168.57.0/24` | `192.168.57.1/32` (poste d'admin) |
| Quotas (socle) | 2 VM | 2 VM | 4 VM |

## Les backends

`envs/prod/backend.tf` ne contient que le type ; `backend.hcl` l'adresse :

```hcl
address        = "https://gitlab.com/api/v4/projects/mohamed.aijjou1780%2Finfra-dm4-envs/terraform/state/dm4-prod"
lock_address   = ".../dm4-prod/lock"
unlock_address = ".../dm4-prod/lock"
lock_method    = "POST"
unlock_method  = "DELETE"
```

- Le projet est désigné par son **chemin** (`namespace%2Fprojet`), pas par
  un ID : le fichier est lisible et identique en CI et sur un poste.
- Les identifiants ne sont jamais dans le code :
  - en CI : `TF_HTTP_USERNAME=gitlab-ci-token`, `TF_HTTP_PASSWORD=$CI_JOB_TOKEN` ;
  - sur un poste : votre utilisateur et un jeton personnel (scope `api`).

```bash
cd envs/dev
export TF_HTTP_USERNAME="<utilisateur gitlab>" TF_HTTP_PASSWORD="<jeton>"
terraform init -backend-config=backend.hcl
```

Sur un poste **sans GitLab** (lab seul) : un fichier d'override, ignoré
par git, remplace le backend par un état local, propre au dossier :

```bash
printf 'terraform {\n  backend "local" {}\n}\n' > envs/dev/backend_override.tf
terraform -chdir=envs/dev init
```

`verifier-backends` refuse tout `*_override.tf` commité.

## Les identités : le socle

`socle/` est appliqué **une fois**, par un administrateur, avec le compte
admin du lab. Il crée pour chaque environnement :

- un **projet** OpenStack `dm4-<env>` ;
- un **compte technique** `ci-dm4-<env>`, rôle `member` sur ce projet seul ;
- des **quotas** (la prod a plus de capacité, le dev ne peut pas la consommer) ;
- `socle/clouds.yaml` (3 entrées, pour le poste) et
  `socle/clouds-<env>.yaml` (une entrée, pour la variable GitLab de cet env).

```bash
cd depots/infra-dm4-envs/socle
cp ../../infra-dm4/clouds.yaml.example clouds.yaml   # entrée admin kolla-aio + mot de passe
terraform init && terraform apply
export OS_CLIENT_CONFIG_FILE="$PWD/clouds.yaml"      # écrasé par le socle : entrées dm4-dev/staging/prod
```

L'état du socle contient les mots de passe générés : il reste hors de git
(`socle/.gitignore`), sur le poste de l'administrateur ou dans un état
GitLab dédié à accès restreint.

Lab sans socle : `clouds.yaml.example` → `clouds.yaml`, avec le compte
admin dans les trois entrées. L'isolation repose alors uniquement sur les
états et les noms.

En CI (Settings → CI/CD → Variables) :

| Variable | Type | Environment scope | Protégée |
|---|---|---|---|
| `OS_CLIENT_CONFIG_FILE` | fichier | `dev` | non |
| `OS_CLIENT_CONFIG_FILE` | fichier | `staging` | non |
| `OS_CLIENT_CONFIG_FILE` | fichier | `prod` | **oui** : seule la branche par défaut la reçoit |
| `TF_VAR_public_key_path` | fichier | `*` | non |

Un job ne reçoit une variable à portée d'environnement que s'il déclare cet
environnement (`environment:`) : c'est pourquoi `plan-<env>` déclare
`environment: { name: <env>, action: prepare }`.

## Le pipeline

```
conformite   verifier-refs-modules  verifier-backends  matrice-versions  gitleaks
qualite      fmt   validate-<env>  tflint-<env>                       <- env modifié seulement
securite     checkov  kics
plan         plan-<env>  checkov-plan-<env>                           <- runner "openstack"
deploiement  apply-<env> (manuel)  destroy-<env> (manuel)             <- branche par défaut
planifié     derive-<env>  (plan -detailed-exitcode, tous les env)
```

| Mécanisme | Effet |
|---|---|
| `inputs: { env, tier, plan_en_mr }` | un seul template, inclus une fois par environnement |
| `rules: changes: envs/<env>/**/*` | une MR qui ne touche que `envs/dev` ne crée **que** les jobs de dev |
| `environment` + `deployment_tier` | page Operate → Environments : qui a déployé quoi, quand, dans quel env |
| `resource_group: <env>` | jamais deux plans/apply simultanés sur le même environnement |
| `plan_en_mr: false` (prod) | les identifiants protégés de prod n'arrivent pas dans les MR : le plan de prod tourne sur `main`, relu avant l'apply manuel |
| `apply plan.cache` | applique le plan relu, pas un nouveau calcul |
| `verifier-backends` | chaque `backend.hcl` vise un état qui porte le nom de son dossier, aucun état partagé, `environnement` du tfvars = nom du dossier |
| `matrice-versions` | tableau module × environnement, colonne « promotion en cours » |

## Déroulé — en local

Tout le déroulé, automatiquement (environ 10 minutes) :

```bash
PAUSE=1 ./scripts/demo-environnements.sh
```

### 1. Préparation

```bash
cd demo-modules/04-modules-versionnes
./scripts/creer-depots-locaux.sh
eval "$(./scripts/env-depots-locaux.sh)"
./scripts/publier-compute-v1.1.0.sh
git clone https://gitlab.com/mohamed.aijjou1780/infra-dm4-envs.git travail/infra-dm4-envs
```

`publier-compute-v1.1.0.sh` publie la version de compute qui sera promue
(déjà présente si DEMO-NOUVELLE-VERSION.md a été jouée).

### 2. Ce qui distingue deux environnements

```bash
diff -r travail/infra-dm4-envs/envs/dev travail/infra-dm4-envs/envs/prod
```

Seuls `backend.hcl` (nom de l'état) et `terraform.tfvars` diffèrent.

### 3. Pipeline complet

```bash
./scripts/controles-locaux.sh travail/infra-dm4-envs
```

```text
OK  dev : état dm4-dev
OK  prod : état dm4-prod
OK  staging : état dm4-staging
| module | dev | staging | prod | état |
| terraform-openstack-compute | v1.0.0 | v1.0.0 | v1.0.0 | aligné |
...
```

### 4. L'erreur classique : copier un environnement sans adapter le backend

```bash
cp travail/infra-dm4-envs/envs/prod/backend.hcl travail/infra-dm4-envs/envs/staging/backend.hcl
ENVS="-" ./scripts/controles-locaux.sh travail/infra-dm4-envs
```

```text
KO  staging : l'état 'dm4-prod' ne porte pas le nom de l'environnement
KO  état partagé par plusieurs environnements : .../terraform/state/dm4-prod
```

Sans ce contrôle, le prochain `apply` de staging aurait remplacé l'état de
prod par celui de staging. Annuler :

```bash
git -C travail/infra-dm4-envs checkout -- envs/staging/backend.hcl
```

Sur un clone git, `controles-locaux.sh` ne prend que ce qu'un commit
contiendrait (fichiers suivis et nouveaux non ignorés), comme la CI : un
`backend_override.tf` ou un `clouds.yaml` locaux, ignorés par git, ne
perturbent pas les contrôles.

`ENVS="-"` ne lance que les jobs communs ; `ENVS="dev"` ajoute ceux de dev,
comme le fait GitLab quand seul `envs/dev/` change.

### 5. Promotion de compute v1.1.0 : dev

```bash
./scripts/promouvoir.sh travail/infra-dm4-envs dev compute v1.1.0
ENVS="dev" ./scripts/controles-locaux.sh travail/infra-dm4-envs
git -C travail/infra-dm4-envs commit -am "promotion(dev): terraform-openstack-compute v1.1.0"
```

`promouvoir.sh` vérifie que le tag existe (`git ls-remote`) avant de
modifier `envs/dev/main.tf`. La matrice affiche :

```text
| terraform-openstack-compute | v1.1.0 | v1.0.0 | v1.0.0 | promotion en cours |
```

Sur GitLab, cette MR ne crée que `validate-dev`, `tflint-dev`, `plan-dev`,
`checkov-plan-dev` (+ les jobs communs) ; après merge, `apply-dev`.

### 6. Promotion : staging, puis prod

Une fois dev validé (déployé, testé) :

```bash
./scripts/promouvoir.sh travail/infra-dm4-envs staging compute v1.1.0
ENVS="staging" ./scripts/controles-locaux.sh travail/infra-dm4-envs
git -C travail/infra-dm4-envs commit -am "promotion(staging): terraform-openstack-compute v1.1.0"
```

```bash
./scripts/promouvoir.sh travail/infra-dm4-envs prod compute v1.1.0
ENVS="prod" ./scripts/controles-locaux.sh travail/infra-dm4-envs
git -C travail/infra-dm4-envs commit -am "promotion(prod): terraform-openstack-compute v1.1.0"
```

```bash
git -C travail/infra-dm4-envs log --oneline
```

Trois commits, un par environnement : l'historique git **est** le journal
des promotions. La matrice repasse à « aligné ».

## Déroulé — sur le lab OpenStack

Avec les identifiants (socle ou admin) dans `OS_CLIENT_CONFIG_FILE`, et un
backend : GitLab (`TF_HTTP_*` + `-backend-config=backend.hcl`) ou local
(`backend_override.tf`).

```bash
cd travail/infra-dm4-envs
terraform -chdir=envs/dev init -backend-config=backend.hcl
terraform -chdir=envs/dev apply
terraform -chdir=envs/prod init -backend-config=backend.hcl
terraform -chdir=envs/prod apply
```

À observer :

- GitLab, Operate → Terraform states : `dm4-dev` et `dm4-prod`, chacun son
  historique et son verrou ;
- Horizon : réseaux `dm4-dev-net` (10.60.1.0/24) et `dm4-prod-net`
  (10.60.3.0/24) ; avec le socle, chacun dans **son projet** ;
- `terraform -chdir=envs/dev output environnement` → `dev`.

L'isolation, en une commande :

```bash
terraform -chdir=envs/dev destroy
terraform -chdir=envs/prod plan      # No changes : la prod n'a rien vu
```

## Sur GitLab

1. `./scripts/publier-sur-gitlab.sh` crée aussi `infra-dm4-envs`, l'ajoute
   à l'allowlist des modules et, avec
   `CLOUDS_ENVS=depots/infra-dm4-envs/socle`, crée les 3 variables
   `OS_CLIENT_CONFIG_FILE` (portée `dev` / `staging` / `prod`, prod protégée).
2. Promotion = une MR par environnement : pipeline limité à cet
   environnement, widget Terraform du plan, merge, `apply-<env>` manuel.
3. **Détection de dérive** : CI/CD → Schedules → nouvelle planification sur
   `main` (par exemple chaque nuit). Seuls les jobs `derive-dev`,
   `derive-staging`, `derive-prod` tournent ; rouge = l'infrastructure ne
   correspond plus au code (supprimer une règle de security group dans
   Horizon pour le voir).
4. Operate → Environments : `dev`, `staging`, `prod`, avec le dernier
   déploiement et le bouton d'arrêt (`destroy-<env>`).
5. En offre Premium : **protected environments** (qui peut déployer `prod`)
   et **approbations de déploiement** (un second regard obligatoire avant
   `apply-prod`).

## Points d'attention

- **Un backend n'accepte pas de variables** : impossible d'écrire
  `key = "${var.env}"`. D'où un `backend.hcl` par dossier, et un contrôle
  automatique de sa cohérence.
- **Une version de module non plus** : `source` et `?ref=` sont statiques.
  La version vit dans `envs/<env>/main.tf`, ce qui la rend visible en revue.
- **`terraform.tfvars` est chargé automatiquement**, uniquement dans le
  dossier courant : avec `-chdir=envs/prod`, c'est bien celui de prod.
- **Renovate** ouvrirait une MR modifiant les trois environnements à la
  fois : à configurer pour cibler `envs/dev/**` seulement (les
  promotions restent manuelles), ou à ne pas utiliser sur ce dépôt.
- **Même provider partout** : un `.terraform.lock.hcl` par environnement,
  identiques ; une montée de provider se promeut comme une version de module.
