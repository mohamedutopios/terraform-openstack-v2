#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Déroulé automatique de DEMO-ENVIRONNEMENTS.md, en local :
#   dépôt infra-dm4-envs : 3 environnements, 3 backends, 3 états
#   -> pipeline vert -> erreur de copier-coller de backend (rouge)
#   -> promotion de compute v1.1.0 : dev, puis staging, puis prod
#
# Repart de zéro. Clone de travail dans travail/. PAUSE=1 : pause entre étapes.
# -----------------------------------------------------------------------------
set -euo pipefail

ICI="$(cd "$(dirname "$0")/.." && pwd)"
TRAVAIL="$ICI/travail"
DEPOT="$TRAVAIL/infra-dm4-envs"

g() { git -c user.name="Equipe infra" -c user.email="infra@exemple.invalid" "$@"; }

N=0
etape() {
  N=$((N + 1))
  printf '\n\033[1;34m######## %d. %s\033[0m\n' "$N" "$*"
  if [ -n "${PAUSE:-}" ]; then read -r -p "(Entrée pour continuer) " _; fi
}

pipeline() {   # pipeline <vert|rouge> <envs modifiés|-> 
  local attendu=$1 envs=$2
  if ENVS="$envs" "$ICI/scripts/controles-locaux.sh" "$DEPOT" > "$TRAVAIL/pipeline.log" 2>&1; then res=vert; else res=rouge; fi
  sed -e 's/\x1b\[[0-9;]*m//g' "$TRAVAIL/pipeline.log" | sed -n '/===== verifier-backends/,/===== gitleaks/p' | grep -vE '^=====|^$' || true
  sed -n '/===== Bilan/,$p' "$TRAVAIL/pipeline.log"
  [ "$res" = "$attendu" ] || { echo "!! pipeline $res, attendu $attendu ($TRAVAIL/pipeline.log)"; exit 1; }
  echo "=> pipeline $res (attendu)"
}

etape "Point de départ : dépôts, tags, et compute v1.1.0 publié"
"$ICI/scripts/creer-depots-locaux.sh" > /dev/null
eval "$("$ICI/scripts/env-depots-locaux.sh")"
"$ICI/scripts/publier-compute-v1.1.0.sh"
rm -rf "$TRAVAIL" && mkdir -p "$TRAVAIL"
g clone -q https://gitlab.com/mohamed.aijjou1780/infra-dm4-envs.git "$DEPOT"
cd "$DEPOT"
find envs -type f | sort

etape "Ce qui distingue dev et prod : backend.hcl et terraform.tfvars, rien d'autre"
diff -r envs/dev envs/prod || true

etape "Pipeline complet : 3 environnements, 3 états distincts"
pipeline vert "dev staging prod"

etape "Erreur classique : envs/staging/backend.hcl copié depuis prod"
cp envs/prod/backend.hcl envs/staging/backend.hcl
pipeline rouge "-"
git checkout -q -- envs/staging/backend.hcl

etape "Promotion 1/3 : compute v1.1.0 en DEV seulement"
"$ICI/scripts/promouvoir.sh" "$DEPOT" dev compute v1.1.0
pipeline vert "dev"
g commit -q -am "promotion(dev): terraform-openstack-compute v1.1.0"

etape "Promotion 2/3 : STAGING, après validation en dev"
"$ICI/scripts/promouvoir.sh" "$DEPOT" staging compute v1.1.0
pipeline vert "staging"
g commit -q -am "promotion(staging): terraform-openstack-compute v1.1.0"

etape "Promotion 3/3 : PROD"
"$ICI/scripts/promouvoir.sh" "$DEPOT" prod compute v1.1.0
pipeline vert "prod"
g commit -q -am "promotion(prod): terraform-openstack-compute v1.1.0"
g push -q origin main

etape "Historique : une promotion = un commit = un environnement"
git log --oneline
