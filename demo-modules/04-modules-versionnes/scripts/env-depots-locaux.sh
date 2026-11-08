#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Redirige https://gitlab.com/mohamed.aijjou1780/<dépôt>.git vers les dépôts
# locaux de .depots-git/, SANS toucher au code ni au ~/.gitconfig :
# variables GIT_CONFIG_* propres au terminal courant (git >= 2.31).
#
# C'est exactement le mécanisme utilisé en CI pour injecter le jeton du job
# (url.<base>.insteadOf) : le code garde l'URL réelle des dépôts.
#
# Usage :   eval "$(./scripts/env-depots-locaux.sh)"
# Annuler : unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
# -----------------------------------------------------------------------------
set -euo pipefail
ICI="$(cd "$(dirname "$0")/.." && pwd)"
[ -d "$ICI/.depots-git" ] || { echo "echo 'Lancer d abord ./scripts/creer-depots-locaux.sh' >&2"; exit 1; }

cat <<EOF
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0='url.file://$ICI/.depots-git/.insteadOf'
export GIT_CONFIG_VALUE_0='https://gitlab.com/mohamed.aijjou1780/'
echo 'gitlab.com/mohamed.aijjou1780/* -> $ICI/.depots-git/*'
EOF
