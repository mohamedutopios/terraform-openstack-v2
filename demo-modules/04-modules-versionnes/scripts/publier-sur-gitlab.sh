#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Publie les dépôts de .depots-git/ sur GitLab et les configure :
#   1. crée les 6 projets (privés) s'ils n'existent pas
#   2. protège les tags v* (seuls les maintainers les créent, personne ne
#      les déplace) : c'est ce qui rend un ?ref=vX.Y.Z fiable
#   3. autorise le jeton CI de infra-dm4 et infra-dm4-envs à cloner chaque
#      module (allowlist)
#   4. crée les variables CI de infra-dm4 si CLOUDS_YAML / CLE_PUBLIQUE sont
#      fournies, et celles de infra-dm4-envs PAR ENVIRONNEMENT si
#      CLOUDS_ENVS (dossier contenant clouds-dev.yaml, clouds-staging.yaml,
#      clouds-prod.yaml, générés par socle/) est fourni : variable limitée à
#      l'environnement, PROTÉGÉE pour prod
#   5. rejoue l'historique COMMIT PAR COMMIT (puis le tag éventuel) : un
#      pipeline par étape, dans l'ordre chronologique (GitLab ne crée pas de
#      pipeline quand on pousse trop de tags d'un coup)
#
# Prérequis : ./scripts/creer-depots-locaux.sh, python3, curl, et
#   export GITLAB_TOKEN=<jeton personnel, scope api>
# Options (variables d'environnement) :
#   GITLAB_HOST=gitlab.com   GITLAB_NS=mohamed.aijjou1780
#   CLOUDS_YAML=chemin/clouds.yaml  CLE_PUBLIQUE=~/.ssh/id_rsa.pub
#   CLOUDS_ENVS=depots/infra-dm4-envs/socle
#   SIMULATION=1   affiche ce qui serait fait, sans rien appeler
#
# Si GITLAB_NS change, remplacer aussi mohamed.aijjou1780 dans les sources
# des modules (depots/infra-dm4/main.tf) et les include des .gitlab-ci.yml.
# -----------------------------------------------------------------------------
set -euo pipefail

ICI="$(cd "$(dirname "$0")/.." && pwd)"
SERVEUR="$ICI/.depots-git"
HOST="${GITLAB_HOST:-gitlab.com}"
NS="${GITLAB_NS:-mohamed.aijjou1780}"
API="https://$HOST/api/v4"
SIMULATION="${SIMULATION:-}"
MODULES=(terraform-openstack-network terraform-openstack-compute terraform-openstack-security)
INFRAS=(infra-dm4 infra-dm4-envs)
DEPOTS=(terraform-ci-templates "${MODULES[@]}" "${INFRAS[@]}")

[ -d "$SERVEUR" ] || { echo "Lancer d'abord ./scripts/creer-depots-locaux.sh"; exit 1; }
[ -n "$SIMULATION" ] || : "${GITLAB_TOKEN:?export GITLAB_TOKEN=<jeton personnel scope api>}"

enc() { python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
json() { python3 -c 'import sys,json; print(json.load(sys.stdin)'"$1"')'; }

api() {   # api <méthode> <chemin> [args curl...]
  local m=$1 p=$2; shift 2
  if [ -n "$SIMULATION" ]; then echo "  [simulation] $m $p $*" >&2; echo '{"id": 0}'; return; fi
  curl -sS --fail-with-body -X "$m" -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$API$p" "$@"
}

id_projet() {
  if [ -n "$SIMULATION" ]; then echo 0; return; fi
  curl -sS -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$API/projects/$(enc "$NS/$1")" | json '.get("id","")'
}

echo "== 1. Projets"
NS_ID=$(api GET "/namespaces/$(enc "$NS")" | json '["id"]')
for d in "${DEPOTS[@]}"; do
  if [ -n "$(id_projet "$d")" ] && [ -z "$SIMULATION" ]; then
    echo "  $d : existe déjà"
  else
    api POST /projects --data-urlencode "name=$d" --data-urlencode "path=$d" \
      --data "namespace_id=$NS_ID" --data "visibility=private" \
      --data "initialize_with_readme=false" >/dev/null
    echo "  $d : créé"
  fi
done

echo "== 2. Tags v* protégés"
for d in terraform-ci-templates "${MODULES[@]}"; do
  api POST "/projects/$(id_projet "$d")/protected_tags" \
    --data-urlencode "name=v*" --data "create_access_level=40" >/dev/null 2>&1 \
    && echo "  $d : v* protégé" || echo "  $d : déjà protégé"
done

echo "== 3. Allowlist du jeton CI (infras -> modules)"
INFRA_ID=$(id_projet infra-dm4)
for i in "${INFRAS[@]}"; do
  cible=$(id_projet "$i")
  for d in "${MODULES[@]}"; do
    api POST "/projects/$(id_projet "$d")/job_token_scope/allowlist" \
      --data "target_project_id=$cible" >/dev/null 2>&1 \
      && echo "  $d : autorise $i" || echo "  $d : $i déjà autorisé"
  done
done

echo "== 4. Variables CI de infra-dm4"
if [ -n "${CLOUDS_YAML:-}" ]; then
  api POST "/projects/$INFRA_ID/variables" --data "key=OS_CLIENT_CONFIG_FILE" \
    --data "variable_type=file" --data-urlencode "value@$CLOUDS_YAML" >/dev/null && echo "  OS_CLIENT_CONFIG_FILE"
else
  echo "  CLOUDS_YAML non fourni : créer OS_CLIENT_CONFIG_FILE (type fichier) à la main"
fi
if [ -n "${CLE_PUBLIQUE:-}" ]; then
  api POST "/projects/$INFRA_ID/variables" --data "key=TF_VAR_public_key_path" \
    --data "variable_type=file" --data-urlencode "value@${CLE_PUBLIQUE/#\~/$HOME}" >/dev/null && echo "  TF_VAR_public_key_path"
else
  echo "  CLE_PUBLIQUE non fourni : créer TF_VAR_public_key_path (type fichier) à la main"
fi

echo "== 4b. Variables CI de infra-dm4-envs (une par environnement)"
ENVS_ID=$(id_projet infra-dm4-envs)
if [ -n "${CLE_PUBLIQUE:-}" ]; then
  api POST "/projects/$ENVS_ID/variables" --data "key=TF_VAR_public_key_path" \
    --data "variable_type=file" --data-urlencode "value@${CLE_PUBLIQUE/#\~/$HOME}" >/dev/null && echo "  TF_VAR_public_key_path (tous)"
fi
for e in dev staging prod; do
  f="${CLOUDS_ENVS:-}/clouds-$e.yaml"
  if [ -n "${CLOUDS_ENVS:-}" ] && [ -f "$f" ]; then
    protege=false; [ "$e" = prod ] && protege=true
    api POST "/projects/$ENVS_ID/variables" --data "key=OS_CLIENT_CONFIG_FILE" \
      --data "variable_type=file" --data "environment_scope=$e" --data "protected=$protege" \
      --data-urlencode "value@$f" >/dev/null && echo "  OS_CLIENT_CONFIG_FILE [$e] protégée=$protege"
  else
    echo "  OS_CLIENT_CONFIG_FILE [$e] : CLOUDS_ENVS non fourni, à créer à la main (scope $e)"
  fi
done

echo "== 5. Historique poussé étape par étape"
for d in "${DEPOTS[@]}"; do
  # Jeton fourni par un helper de credentials éphémère (le premier
  # credential.helper vide écarte ceux du poste, ex. trousseau macOS) :
  # il n'apparaît ni dans l'URL ni dans la configuration git.
  url="https://$HOST/$NS/$d.git"
  for sha in $(git -C "$SERVEUR/$d.git" rev-list --reverse main); do
    msg=$(git -C "$SERVEUR/$d.git" log -1 --format=%s "$sha")
    tags=$(git -C "$SERVEUR/$d.git" tag --points-at "$sha")
    echo "  $d : $msg ${tags:+(tag $tags)}"
    [ -n "$SIMULATION" ] && continue
    git -C "$SERVEUR/$d.git" \
      -c credential.helper= \
      -c credential.helper='!f() { echo username=oauth2; echo "password=$GITLAB_TOKEN"; }; f' \
      push -q "$url" "$sha:refs/heads/main" $(for t in $tags; do echo "refs/tags/$t"; done)
  done
done

echo
echo "Terminé : https://$HOST/$NS/infra-dm4/-/pipelines"
