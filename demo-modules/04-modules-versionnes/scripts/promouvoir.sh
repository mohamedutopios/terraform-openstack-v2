#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Promouvoir une version de module dans UN environnement : modifie le ?ref=
# de envs/<env>/main.tf, après avoir vérifié que le tag existe.
# Une promotion = un commit (une MR) = un environnement.
#
# Usage : ./scripts/promouvoir.sh <dépôt-infra> <env> <module> <vX.Y.Z>
#   ex.   ./scripts/promouvoir.sh travail/infra-dm4-envs dev compute v1.1.0
# -----------------------------------------------------------------------------
set -euo pipefail
DEPOT="${1:?dépôt}"; ENV="${2:?env}"; MOD="${3:?module (network|security|compute)}"; VER="${4:?version vX.Y.Z}"
BASE="${GITLAB_BASE:-https://gitlab.com/mohamed.aijjou1780}"
F="$DEPOT/envs/$ENV/main.tf"

[ -f "$F" ] || { echo "Pas d'environnement $ENV dans $DEPOT/envs/"; exit 1; }
echo "$VER" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || { echo "Version $VER invalide : attendu vX.Y.Z"; exit 1; }
git ls-remote --exit-code --tags "$BASE/terraform-openstack-$MOD.git" "refs/tags/$VER" >/dev/null \
  || { echo "Le tag $VER n'existe pas dans terraform-openstack-$MOD"; exit 1; }

avant=$(sed -nE "s|.*terraform-openstack-$MOD\.git\?ref=(v[0-9.]+)\".*|\1|p" "$F")
[ -n "$avant" ] || { echo "Module $MOD non utilisé dans $F"; exit 1; }
sed -i.bak -E "s|(terraform-openstack-$MOD\.git\?ref=)v[0-9]+\.[0-9]+\.[0-9]+|\1$VER|" "$F" && rm -f "$F.bak"
echo "$ENV : terraform-openstack-$MOD $avant -> $VER"
git -C "$DEPOT" --no-pager diff -- "envs/$ENV/main.tf" || true
