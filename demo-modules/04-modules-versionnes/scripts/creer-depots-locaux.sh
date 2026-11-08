#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Crée de VRAIS dépôts git (bare), avec leur historique et leurs tags, dans
# .depots-git/ : ils jouent le rôle du serveur GitLab pour la démo locale.
#
# Contenu d'un tag = depots/<dépôt>/            (version courante)
#                  + historique/<dépôt>/<tag>/  (fichiers qui différaient)
# historique/<dépôt>/<tag>/.supprimer liste les fichiers à retirer à ce tag.
# Étape "@ci" = commit SANS tag : contenu précédent + le .gitlab-ci.yml
# courant (passage au template de pipeline v1.1.0).
#
# Usage : ./scripts/creer-depots-locaux.sh      (relançable, repart de zéro)
# -----------------------------------------------------------------------------
set -euo pipefail

ICI="$(cd "$(dirname "$0")/.." && pwd)"
SERVEUR="$ICI/.depots-git"
TRAVAIL="$(mktemp -d)"
trap 'rm -rf "$TRAVAIL"' EXIT

g() {
  git -c user.name="Equipe plateforme" -c user.email="plateforme@exemple.invalid" \
      -c init.defaultBranch=main -c advice.detachedHead=false "$@"
}

# publier <dépôt> [étape...]  — un commit par étape, dans l'ordre donné :
#   vX.Y.Z  commit + tag annoté
#   @ci     commit sans tag : on garde le contenu, on prend le .gitlab-ci.yml courant
# Sans étape : un seul commit sur main (cas de l'infra, qui ne se tague pas).
publier() {
  local depot=$1; shift
  local wd="$TRAVAIL/$depot"
  g init -q "$wd"
  local versions=("$@")
  [ ${#versions[@]} -gt 0 ] || versions=("")
  for tag in "${versions[@]}"; do
    if [ "$tag" = "@ci" ]; then
      cp "$ICI/depots/$depot/.gitlab-ci.yml" "$wd/.gitlab-ci.yml"
      g -C "$wd" commit -q -am "ci: passage au template terraform-ci-templates v1.1.0"
      printf '  %-32s commit sans tag : pipeline v1.1.0\n' "$depot"
      continue
    fi
    find "$wd" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
    rsync -a --exclude .terraform --exclude .tf-plugin-cache \
      "$ICI/depots/$depot/" "$wd/"
    if [ -n "$tag" ] && [ -d "$ICI/historique/$depot/$tag" ]; then
      # --checksum : comparer le contenu, pas taille + date (identiques ici)
      rsync -a --checksum --exclude .supprimer "$ICI/historique/$depot/$tag/" "$wd/"
      # .supprimer : fichiers de la version courante absents à ce tag
      if [ -f "$ICI/historique/$depot/$tag/.supprimer" ]; then
        while IFS= read -r f; do [ -n "$f" ] && rm -f "$wd/$f"; done < "$ICI/historique/$depot/$tag/.supprimer"
      fi
    fi
    g -C "$wd" add -A
    if [ -n "$tag" ]; then
      g -C "$wd" commit -q -m "release $tag"
      g -C "$wd" tag -a "$tag" -m "$depot $tag"
      printf '  %-32s tag %s\n' "$depot" "$tag"
    else
      g -C "$wd" commit -q -m "infra initiale"
      printf '  %-32s main (sans tag)\n' "$depot"
    fi
  done
  g init -q --bare "$SERVEUR/$depot.git"
  g -C "$wd" push -q "$SERVEUR/$depot.git" main --tags
}

rm -rf "$SERVEUR"
mkdir -p "$SERVEUR"
echo "Dépôts créés dans $SERVEUR :"
publier terraform-ci-templates       v1.0.0 v1.1.0 v1.2.0
publier terraform-openstack-network  v1.0.0 @ci
publier terraform-openstack-compute  v1.0.0 @ci
# v1.1.0 puis pipeline v1.1.0 (rouge : SSH ouvert) puis correctif MAJEUR
publier terraform-openstack-security v1.0.0 v1.1.0 @ci v2.0.0
publier infra-dm4
publier infra-dm4-envs

echo
echo "Historique du module security :"
git -C "$SERVEUR/terraform-openstack-security.git" log --oneline --decorate main
echo
echo "Ensuite :  eval \"\$(./scripts/env-depots-locaux.sh)\""
