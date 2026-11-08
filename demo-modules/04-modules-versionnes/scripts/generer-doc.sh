#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Régénère la section entre <!-- BEGIN_TF_DOCS --> et <!-- END_TF_DOCS -->
# du README d'un module (entrées, sorties, ressources), à partir du code.
# Même version de terraform-docs que le job "docs" de la CI : sinon le
# format diffère et le job échoue.
#
# Usage : ./scripts/generer-doc.sh <dossier-du-module>
# -----------------------------------------------------------------------------
set -euo pipefail
CIBLE="$(cd "${1:?usage : $0 <dossier-du-module>}" && pwd)"
case "$(uname -m)" in arm64|aarch64) ARCH=arm64 ;; *) ARCH=amd64 ;; esac
docker run --rm -v "$CIBLE":/w -w /w --entrypoint "" \
  "quay.io/terraform-docs/terraform-docs:0.24.0-$ARCH" terraform-docs .
