#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Déroulé automatique de DEMO-NOUVELLE-VERSION.md, en local :
#
#   module compute : branche -> modification -> pipeline (rouge : doc)
#                    -> doc régénérée -> pipeline vert -> merge -> tag v1.1.0
#                    -> pipeline du tag (dont verifier-tag)
#   infra-dm4      : branche -> ref v1.1.0 seule (pipeline vert : mineure)
#                    -> ajustement d'après la doc -> pipeline vert -> merge
#
# Repart de zéro (relance creer-depots-locaux.sh). Clones de travail dans
# travail/. PAUSE=1 : attend Entrée entre les étapes.
# -----------------------------------------------------------------------------
set -euo pipefail

ICI="$(cd "$(dirname "$0")/.." && pwd)"
TRAVAIL="$ICI/travail"
GITLAB="https://gitlab.com/mohamed.aijjou1780"
EVO_MODULE="$ICI/evolutions/terraform-openstack-compute/v1.1.0"
EVO_INFRA="$ICI/evolutions/infra-dm4/compute-v1.1.0"

g() { git -c user.name="Dev module" -c user.email="dev@exemple.invalid" -c advice.detachedHead=false "$@"; }

N=0
etape() {
  N=$((N + 1))
  printf '\n\033[1;34m######## %d. %s\033[0m\n' "$N" "$*"
  if [ -n "${PAUSE:-}" ]; then read -r -p "(Entrée pour continuer) " _; fi
}

pipeline() {   # pipeline <attendu: vert|rouge> <args de controles-locaux>
  local attendu=$1; shift
  if "$ICI/scripts/controles-locaux.sh" "$@" > "$TRAVAIL/pipeline.log" 2>&1; then res=vert; else res=rouge; fi
  sed -n '/===== Bilan/,$p' "$TRAVAIL/pipeline.log"
  grep -E "^Error:|README.md is out of date|^--- Notes|^  - |^### " "$TRAVAIL/pipeline.log" | head -20 || true
  if [ "$res" != "$attendu" ]; then
    echo "!! pipeline $res, attendu $attendu (détail : $TRAVAIL/pipeline.log)"; exit 1
  fi
  echo "=> pipeline $res (attendu)"
}

etape "Point de départ : dépôts et tags (compute en v1.0.0)"
"$ICI/scripts/creer-depots-locaux.sh" > /dev/null
eval "$("$ICI/scripts/env-depots-locaux.sh")"
rm -rf "$TRAVAIL" && mkdir -p "$TRAVAIL"
git -C "$ICI/.depots-git/terraform-openstack-compute.git" log --oneline --decorate

# ============================================================== MODULE ======

etape "compute : clone et branche de travail"
g clone -q "$GITLAB/terraform-openstack-compute.git" "$TRAVAIL/terraform-openstack-compute"
cd "$TRAVAIL/terraform-openstack-compute"
g switch -q -c feat/instance-count
git branch --show-current

etape "compute : la modification (instance_count, sorties en liste, moved, tests, doc rédigée)"
rsync -a "$EVO_MODULE/" ./
g add -A
git status --short

etape "compute : pipeline de la branche -> rouge attendu (section générée du README périmée)"
pipeline rouge "$TRAVAIL/terraform-openstack-compute"

etape "compute : régénérer la doc depuis le code"
"$ICI/scripts/generer-doc.sh" .
git diff --stat README.md

etape "compute : pipeline de la branche -> vert attendu"
pipeline vert "$TRAVAIL/terraform-openstack-compute"

etape "compute : commit, merge dans main, tag v1.1.0, push"
g add -A
g commit -q -m "feat: instance_count pour déployer plusieurs VM"
g switch -q main
g merge -q --no-ff feat/instance-count -m "Merge branch 'feat/instance-count'"
g tag -a v1.1.0 -m "terraform-openstack-compute v1.1.0"
g push -q origin main v1.1.0
git log --oneline --decorate -4

etape "compute : pipeline du TAG v1.1.0 (contrôles + verifier-tag + notes de version)"
pipeline vert "$ICI/.depots-git/terraform-openstack-compute.git" v1.1.0

# =============================================================== INFRA ======

etape "infra : clone et branche"
g clone -q "$GITLAB/infra-dm4.git" "$TRAVAIL/infra-dm4"
cd "$TRAVAIL/infra-dm4"
g switch -q -c chore/compute-v1.1.0

etape "infra : lire la doc de la nouvelle version (README du tag)"
git -C "$ICI/.depots-git/terraform-openstack-compute.git" show v1.1.0:README.md \
  | sed -n '/^## Passer de 1.0.0 à 1.1.0/,/^Historique/p'

etape "infra : 1er temps, seulement ?ref=v1.1.0 -> vert attendu (version mineure)"
sed -i.bak 's|terraform-openstack-compute.git?ref=v1.0.0|terraform-openstack-compute.git?ref=v1.1.0|' main.tf && rm main.tf.bak
git diff
pipeline vert "$TRAVAIL/infra-dm4"

etape "infra : 2e temps, ajustement d'après la doc (2 VM, sorties en liste)"
rsync -a "$EVO_INFRA/" ./
git diff --stat
git diff outputs.tf | head -30

etape "infra : pipeline de la branche -> vert attendu"
pipeline vert "$TRAVAIL/infra-dm4"

etape "infra : commit, merge, push"
g add -A
g commit -q -m "chore: module compute v1.1.0, 2 VM"
g switch -q main
g merge -q --no-ff chore/compute-v1.1.0 -m "Merge branch 'chore/compute-v1.1.0'"
g push -q origin main
git log --oneline --decorate -3

echo
echo "Terminé. Sur le lab OpenStack :"
echo "  cd travail/infra-dm4 && cp ../../depots/infra-dm4/clouds.yaml.example clouds.yaml   # mot de passe"
echo "  terraform init && terraform plan"
echo "  attendu : VM et port 'moved from ...this' vers [0] et renommés sur place,"
echo "            2e VM + port + IP flottante + association créés, 0 to destroy"
