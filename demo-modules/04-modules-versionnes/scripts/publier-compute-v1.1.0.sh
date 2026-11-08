#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Publie directement compute v1.1.0 (sans le déroulé pas à pas de
# DEMO-NOUVELLE-VERSION.md) : prérequis de DEMO-ENVIRONNEMENTS.md.
# -----------------------------------------------------------------------------
set -euo pipefail
ICI="$(cd "$(dirname "$0")/.." && pwd)"
eval "$("$ICI/scripts/env-depots-locaux.sh")" >/dev/null
if git -C "$ICI/.depots-git/terraform-openstack-compute.git" rev-parse -q --verify refs/tags/v1.1.0 >/dev/null; then
  echo "compute v1.1.0 déjà publié"; exit 0
fi
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
g() { git -c user.name="Dev module" -c user.email="dev@exemple.invalid" "$@"; }
g clone -q https://gitlab.com/mohamed.aijjou1780/terraform-openstack-compute.git "$W/compute"
rsync -a "$ICI/evolutions/terraform-openstack-compute/v1.1.0/" "$W/compute/"
"$ICI/scripts/generer-doc.sh" "$W/compute" >/dev/null
g -C "$W/compute" add -A
g -C "$W/compute" commit -q -m "feat: instance_count pour déployer plusieurs VM"
g -C "$W/compute" tag -a v1.1.0 -m "terraform-openstack-compute v1.1.0"
g -C "$W/compute" push -q origin main v1.1.0
echo "compute v1.1.0 publié"
