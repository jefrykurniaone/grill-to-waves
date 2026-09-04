#!/usr/bin/env bash
# Install the grill-to-waves + orchestrate skills and their executor/scout agents for
# Claude Code and/or Codex CLI.
#
#   skills/grill-to-waves  ->  <target>/skills/grill-to-waves
#   skills/orchestrate     ->  <target>/skills/orchestrate
#   agents/*.md            ->  <target>/agents                          (Claude Code)
#                          ->  <target>/skills/grill-to-waves/agents    (Codex, role briefs)
#
# Usage:
#   ./install.sh [--target claude|codex|both|auto] [--project PATH] [--no-backup] [--ref REF]
#   curl -fsSL https://raw.githubusercontent.com/jefrykurniaone/grill-to-waves/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/jefrykurniaone/grill-to-waves.git"
SKILLS=(grill-to-waves orchestrate)
STAMP="$(date +%Y%m%d-%H%M%S)"

TARGET="auto"
PROJECT=""
NO_BACKUP=0
REF="main"

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:?--target needs a value}"; shift 2 ;;
    --project) PROJECT="${2:?--project needs a path}"; shift 2 ;;
    --no-backup) NO_BACKUP=1; shift ;;
    --ref) REF="${2:?--ref needs a value}"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$TARGET" in claude|codex|both|auto) ;; *) echo "--target must be claude, codex, both or auto" >&2; exit 2 ;; esac

step() { printf '==> %s\n' "$1"; }
note() { printf '    %s\n' "$1"; }

# --- 1. Locate the source tree ------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/skills/grill-to-waves/SKILL.md" ]; then
  SRC="$SCRIPT_DIR"
  step "Source: local checkout at $SRC"
else
  command -v git >/dev/null 2>&1 || { echo "git is required when running without a local checkout." >&2; exit 1; }
  SRC="$(mktemp -d)/grill-to-waves"
  step "Source: cloning $REPO ($REF) to $SRC"
  git clone --quiet --depth 1 --branch "$REF" "$REPO" "$SRC"
fi

for skill in "${SKILLS[@]}"; do
  [ -f "$SRC/skills/$skill/SKILL.md" ] || { echo "Source tree is incomplete: $SRC/skills/$skill/SKILL.md is missing." >&2; exit 1; }
done

# --- 2. Decide the targets ----------------------------------------------------------------------
if [ -n "$PROJECT" ]; then
  [ -d "$PROJECT" ] || { echo "--project path does not exist: $PROJECT. Point it at an existing repository." >&2; exit 2; }
  CLAUDE_HOME="$(cd "$PROJECT" && pwd)/.claude"
else
  CLAUDE_HOME="$HOME/.claude"
fi
CODEX_HOME="$HOME/.codex"

DO_CLAUDE=0
DO_CODEX=0
case "$TARGET" in
  claude) DO_CLAUDE=1 ;;
  codex)  DO_CODEX=1 ;;
  both)   DO_CLAUDE=1; DO_CODEX=1 ;;
  auto)   DO_CLAUDE=1; [ -d "$CODEX_HOME" ] && DO_CODEX=1 || true ;;
esac

if [ -n "$PROJECT" ] && [ "$TARGET" = "codex" ]; then
  echo "--project applies to Claude Code only. Drop --project, or use --target claude." >&2
  exit 2
fi
if [ -n "$PROJECT" ] && [ "$DO_CODEX" = 1 ]; then
  note "Codex has no project skill scope; skipping Codex because --project was given."
  DO_CODEX=0
fi

# --- 3. Copy ------------------------------------------------------------------------------------
install_dir() {           # $1 from, $2 to, $3 backup root
  local from="$1" to="$2" backup_root="$3"
  if [ -e "$to" ]; then
    if [ "$NO_BACKUP" = 1 ]; then
      note "replacing $to (no backup)"
    else
      mkdir -p "$backup_root"
      mv "$to" "$backup_root/$(basename "$to")-$STAMP"
      note "backed up existing copy to $backup_root/$(basename "$to")-$STAMP"
    fi
    rm -rf "$to"
  fi
  mkdir -p "$(dirname "$to")"
  cp -R "$from" "$to"
  note "installed $to"
}

if [ "$DO_CLAUDE" = 1 ]; then
  step "Claude Code -> $CLAUDE_HOME"
  for skill in "${SKILLS[@]}"; do
    install_dir "$SRC/skills/$skill" "$CLAUDE_HOME/skills/$skill" "$CLAUDE_HOME/backups"
  done
  mkdir -p "$CLAUDE_HOME/agents"
  count=0
  for agent in "$SRC"/agents/*.md; do
    dest="$CLAUDE_HOME/agents/$(basename "$agent")"
    if [ -f "$dest" ] && [ "$NO_BACKUP" != 1 ]; then
      mkdir -p "$CLAUDE_HOME/backups"
      cp "$dest" "$CLAUDE_HOME/backups/$(basename "$agent")-$STAMP"
    fi
    cp "$agent" "$dest"
    count=$((count + 1))
  done
  note "installed $count agent definitions into $CLAUDE_HOME/agents"
fi

if [ "$DO_CODEX" = 1 ]; then
  step "Codex CLI -> $CODEX_HOME"
  for skill in "${SKILLS[@]}"; do
    install_dir "$SRC/skills/$skill" "$CODEX_HOME/skills/$skill" "$CODEX_HOME/backups"
  done
  # Codex has no subagent dispatch, so the definitions install beside the skill as role briefs.
  mkdir -p "$CODEX_HOME/skills/grill-to-waves/agents"
  cp "$SRC"/agents/*.md "$CODEX_HOME/skills/grill-to-waves/agents/"
  note "installed agent role briefs into $CODEX_HOME/skills/grill-to-waves/agents"
fi

# --- 4. Report ----------------------------------------------------------------------------------
step "Done."
[ "$DO_CLAUDE" = 1 ] && note "Claude Code: restart the session, then run  /grill-to-waves  and later  /orchestrate"
[ "$DO_CODEX" = 1 ] && note "Codex CLI: restart the session; the skills trigger by name (grill-to-waves, orchestrate)."
[ "$DO_CODEX" = 1 ] && note "Codex has no subagent dispatch: the session executes tickets itself, one at a time."

# The pipeline calls grilling and domain-modeling (Stage 1) and setup-matt-pocock-skills (Stage 0).
if compgen -G "$HOME/.claude/plugins/cache/mattpocock*" > /dev/null; then
  note "Required plugin mattpocock-skills: found."
else
  echo ""
  step "Required plugin missing: mattpocock-skills"
  note "Stage 1 needs grilling and domain-modeling; Stage 0 needs setup-matt-pocock-skills."
  note "In Claude Code, run:"
  note "  /plugin marketplace add mattpocock/skills"
  note "  /plugin install mattpocock-skills@mattpocock"
  note "The marketplace is named mattpocock, not skills. Restart the session afterwards."
fi
