#!/usr/bin/env bash
# Run install.sh with the home directory pointed at a scratch directory, or not at all.
#
# The tests never run the installer against the real home. This script is the only place they call
# install.sh from, and it refuses unless the directory it is handed carries the marker file the
# tests put there. HOME and CODEX_HOME are then set to it for the installer alone.
#
# Usage: guarded-install.sh SCRATCH_HOME INSTALLER [installer arguments]
#   INSTALLER is the install.sh to run: the tests hand over their own snapshot of the checkout.
set -euo pipefail

scratch="${1:?usage: guarded-install.sh SCRATCH_HOME INSTALLER [installer arguments]}"
installer="${2:?usage: guarded-install.sh SCRATCH_HOME INSTALLER [installer arguments]}"
shift 2

[ -f "$scratch/.g2w-scratch" ] || {
  echo "Refusing to run the installer: $scratch has no .g2w-scratch marker, so it is not a test scratch directory." >&2
  exit 3
}

HOME="$scratch" CODEX_HOME="$scratch/.codex" exec bash "$installer" "$@"
