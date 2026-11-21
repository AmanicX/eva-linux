#!/usr/bin/env bash
# ==============================================================================
#  ✦ Eva Linux v2.1 — Desktop Setup Installer Entrypoint
#  https://github.com/AmanicX/eva-linux
# ==============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
exec bash "${SCRIPT_DIR}/bin/eva-installer" "$@"
