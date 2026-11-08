#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Rejoue en local, avec Docker et les MÊMES images que la CI, les jobs du
# pipeline d'un dépôt (module ou infra). Pratique sans GitLab, et pour voir
# un job échouer avant de pousser.
#
# Usage :
#   ./scripts/controles-locaux.sh depots/terraform-openstack-security
#   ./scripts/controles-locaux.sh depots/infra-dm4
#   ./scripts/controles-locaux.sh .depots-git/terraform-openstack-security.git v1.0.0
#       (2e forme : contrôle le contenu d'un TAG d'un dépôt git)
#   ENVS="dev" ./scripts/controles-locaux.sh travail/infra-dm4-envs
#       (dépôt multi-environnements : seulement les jobs de dev + communs)
#
# Le dépôt est copié dans un dossier temporaire : rien n'est écrit dedans.
# Salle sans Internet : MIROIR_PROVIDERS=<dossier> pointe sur un miroir de
# providers (terraform providers mirror <dossier>), utilisé à la place du registre.
# Pour l'infra, les modules sont lus dans .depots-git/ (creer-depots-locaux.sh).
# -----------------------------------------------------------------------------
set -uo pipefail

ICI="$(cd "$(dirname "$0")/.." && pwd)"
CIBLE="${1:?usage : $0 <dossier-du-depot> | <depot.git> <tag>}"
TAG="${2:-}"

TF_VERSION=1.16.7
TF_VERSION_MIN=1.5.7
TFLINT_IMAGE=ghcr.io/terraform-linters/tflint:v0.64.0
case "$(uname -m)" in arm64|aarch64) ARCH=arm64 ;; *) ARCH=amd64 ;; esac
TFDOCS_IMAGE=quay.io/terraform-docs/terraform-docs:0.24.0-$ARCH
CHECKOV_IMAGE=bridgecrew/checkov:3.4.2
KICS_IMAGE=checkmarx/kics:v2.1.21
GITLEAKS_IMAGE=zricethezav/gitleaks:v8.29.1

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
if [ -n "$TAG" ]; then
  git clone -q --branch "$TAG" "$CIBLE" "$W/src" 2>/dev/null || { echo "Tag $TAG introuvable dans $CIBLE"; exit 2; }
  rm -rf "$W/src/.git"
else
  [ -d "$CIBLE" ] || { echo "Dossier introuvable : $CIBLE"; exit 2; }
  racine=$(git -C "$CIBLE" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$racine" ] && [ "$(cd "$racine" && pwd -P)" = "$(cd "$CIBLE" && pwd -P)" ]; then
    # Clone git : uniquement ce que la CI recevrait (suivis + nouveaux non
    # ignorés). Un backend_override.tf ou un clouds.yaml ignorés restent dehors.
    mkdir -p "$W/src"
    git -C "$CIBLE" ls-files -z --cached --others --exclude-standard \
      | rsync -a --from0 --files-from=- "$CIBLE/" "$W/src/"
  else
    rsync -a --exclude .terraform --exclude .tf-plugin-cache --exclude .git "$CIBLE/" "$W/src/"
  fi
fi
SRC="$W/src"
mkdir -p "$ICI/.cache/plugins"
MIROIR=()
if [ -n "${MIROIR_PROVIDERS:-}" ]; then
  printf 'provider_installation {\n  filesystem_mirror {\n    path = "/miroir"\n  }\n}\n' > "$W/miroir.tfrc"
  MIROIR=(-v "$MIROIR_PROVIDERS":/miroir:ro -v "$W/miroir.tfrc":/miroir.tfrc:ro -e TF_CLI_CONFIG_FILE=/miroir.tfrc)
fi

# Conteneur avec : le dépôt en /w, le cache des providers, et les dépôts
# locaux montés en /depots + redirection git (comme env-depots-locaux.sh).
run() {
  local image=$1; shift
  docker run --rm -v "$SRC":/w -w /w \
    -v "$ICI/.cache/plugins":/plugins -e TF_PLUGIN_CACHE_DIR=/plugins \
    -v "$ICI/.depots-git":/depots:ro \
    -e GIT_CONFIG_COUNT=2 \
    -e GIT_CONFIG_KEY_0=url.file:///depots/.insteadOf \
    -e GIT_CONFIG_VALUE_0=https://gitlab.com/mohamed.aijjou1780/ \
    -e GIT_CONFIG_KEY_1=safe.directory -e GIT_CONFIG_VALUE_1='*' \
    -e TF_IN_AUTOMATION=1 -e TF_INPUT=0 ${MIROIR[@]+"${MIROIR[@]}"} \
    --entrypoint "" "$image" sh -c "$*"
}

RESULTATS=()
job() {   # job <nom> <image> <commande>
  local nom=$1 image=$2; shift 2
  printf '\n\033[1m===== %s\033[0m\n' "$nom"
  if run "$image" "$@"; then
    RESULTATS+=("OK    $nom")
  else
    RESULTATS+=("ECHEC $nom")
  fi
}

TF=hashicorp/terraform:$TF_VERSION
OS_FAUX='export OS_AUTH_URL=http://openstack.invalid:5000/v3 OS_USERNAME=ci OS_PASSWORD=ci OS_PROJECT_NAME=ci OS_USER_DOMAIN_NAME=Default OS_PROJECT_DOMAIN_NAME=Default OS_REGION_NAME=RegionOne'
# Les scanners travaillent sur le code seul (comme en CI, où le clone est propre)
PROPRE='find /w -name .terraform -type d -prune -exec rm -rf {} + ; rm -f /w/examples/*/plan.cache'
KICS="$PROPRE; /app/bin/kics scan -p /w --ci --no-progress --exclude-paths /w/.terraform --report-formats json -o /tmp/kics --fail-on high,medium"

# Script d'un job, lu DANS le template GitLab : le contrôle local exécute
# exactement le même shell que la CI (Python + PyYAML de l'image Checkov).
script_du_template() {   # <fichier.yml> <job>
  docker run --rm -v "$(dirname "$1")":/t:ro --entrypoint python3 "$CHECKOV_IMAGE" -c '
import sys, yaml
d = yaml.safe_load(open("/t/" + sys.argv[1]))
print("\n".join(d[sys.argv[2]]["script"]))' "$(basename "$1")" "$2"
}
# En CI, TF_VAR_public_key_path vient d'une variable GitLab de type fichier
CLE_FACTICE="echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFactice factice' > /tmp/cle.pub && export TF_VAR_public_key_path=/tmp/cle.pub"

if [ -d "$SRC/examples" ]; then
  echo "Dépôt de MODULE : $CIBLE ${TAG}"
  job fmt              "$TF" "terraform fmt -check -recursive -diff"
  for v in "$TF_VERSION_MIN" "$TF_VERSION"; do
    job "validate [$v]" "hashicorp/terraform:$v" \
      "rm -rf .terraform examples/*/.terraform && terraform init -backend=false >/dev/null && terraform validate && for ex in examples/*/; do terraform -chdir=\$ex init -backend=false >/dev/null && terraform -chdir=\$ex validate || exit 1; done"
  done
  job tflint           "$TFLINT_IMAGE"  "tflint --recursive --config /w/.tflint.hcl -f compact"
  job docs             "$TFDOCS_IMAGE"  "terraform-docs --output-check ."
  job terraform-test   "$TF" "rm -rf .terraform && terraform init -backend=false >/dev/null && terraform test"
  job plan-exemple     "$TF" "$OS_FAUX; cd examples/basique && rm -rf .terraform && terraform init -backend=false >/dev/null && terraform plan -refresh=false -out=plan.cache >/dev/null && terraform show -json plan.cache > /w/plan-exemple.json && echo 'plan JSON produit'"
  job checkov          "$CHECKOV_IMAGE" "$PROPRE; checkov -d . --config-file .checkov.yaml"
  if [ -f "$SRC/plan-exemple.json" ]; then
    job checkov-plan   "$CHECKOV_IMAGE" "checkov -f plan-exemple.json --framework terraform_plan --compact"
  fi
  job kics             "$KICS_IMAGE"    "$KICS"
  if [ -n "$TAG" ]; then
    # Même contrôle que le job verifier-tag (pipeline de tag uniquement)
    V="${TAG#v}"
    job verifier-tag   alpine:3.22 "
      echo '$TAG' | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+\$' || { echo 'Tag $TAG invalide : attendu vMAJEUR.MINEUR.CORRECTIF'; exit 1; }
      grep -q '^## \[$V\]' CHANGELOG.md || { echo 'CHANGELOG.md sans section ## [$V]'; exit 1; }
      echo '--- Notes de version $TAG :'
      awk -v v='$V' '\$0 ~ \"^## \\\\[\" v \"\\\\]\" {on=1; next} /^## \\[/ {on=0} on' CHANGELOG.md"
  fi
elif [ -d "$SRC/envs" ]; then
  echo "Dépôt MULTI-ENVIRONNEMENTS : $CIBLE ($(ls "$SRC/envs" | tr '\n' ' '))"
  [ -d "$ICI/.depots-git" ] || { echo "Lancer d'abord ./scripts/creer-depots-locaux.sh"; exit 2; }
  TPL="$ICI/depots/terraform-ci-templates/templates/environnements.yml"
  for j in verifier-refs-modules verifier-backends matrice-versions; do
    job "$j" alpine:3.22 "$(script_du_template "$TPL" "$j")"
  done
  job gitleaks         "$GITLEAKS_IMAGE" "gitleaks dir . --redact --verbose"
  job fmt              "$TF" "terraform fmt -check -recursive -diff"
  # ENVS="staging" : seulement les jobs de cet environnement, comme GitLab
  # (rules:changes) quand seul envs/staging/ a changé. ENVS="-" : aucun.
  for d in "$SRC"/envs/*/; do
    e=$(basename "$d")
    if [ -n "${ENVS:-}" ] && ! echo " $ENVS " | grep -q " $e "; then continue; fi
    job "validate-$e"  "$TF" "rm -rf envs/$e/.terraform && terraform -chdir=envs/$e init -backend=false -lockfile=readonly >/dev/null && terraform -chdir=envs/$e validate"
    job "tflint-$e"    "$TFLINT_IMAGE" "$CLE_FACTICE && tflint --chdir=envs/$e --config /w/.tflint.hcl --call-module-type=all -f compact"
  done
  job checkov          "$CHECKOV_IMAGE" "$PROPRE; checkov -d . --config-file .checkov.yaml"
  job kics             "$KICS_IMAGE"    "$KICS"
  echo
  echo "(plan-<env> / apply-<env> / derive-<env> : runner « openstack » uniquement)"
else
  echo "Dépôt d'INFRA : $CIBLE"
  [ -d "$ICI/.depots-git" ] || { echo "Lancer d'abord ./scripts/creer-depots-locaux.sh"; exit 2; }
  job verifier-refs-modules alpine:3.22 "$(script_du_template "$ICI/depots/terraform-ci-templates/templates/infra.yml" verifier-refs-modules)"
  job gitleaks         "$GITLEAKS_IMAGE" "gitleaks dir . --redact --verbose"
  job fmt              "$TF" "terraform fmt -check -recursive -diff"
  job validate         "$TF" "rm -rf .terraform && terraform init -backend=false -lockfile=readonly && terraform validate"
  job tflint           "$TFLINT_IMAGE"  "$CLE_FACTICE && tflint --call-module-type=all -f compact"
  job checkov          "$CHECKOV_IMAGE" "checkov -d . --config-file .checkov.yaml"
  job kics             "$KICS_IMAGE"    "$KICS"
  echo
  echo "(plan / checkov-plan / apply : runner « openstack » uniquement)"
fi

printf '\n\033[1m===== Bilan\033[0m\n'
code=0
for r in "${RESULTATS[@]}"; do
  echo "  $r"
  case "$r" in ECHEC*) code=1 ;; esac
done
exit $code
