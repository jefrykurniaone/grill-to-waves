#!/usr/bin/env bash
# Install the grill-to-waves + orchestrate skills and their executor/scout agents for
# Claude Code and/or Codex CLI.
#
# Claude Code:
#   skills/grill-to-waves  ->  ~/.claude/skills/grill-to-waves     (or <project>/.claude/skills/...)
#   skills/orchestrate     ->  ~/.claude/skills/orchestrate
#   agents/*.md            ->  ~/.claude/agents/
#
# Codex CLI:
#   skills/grill-to-waves  ->  ~/.agents/skills/grill-to-waves     (or <project>/.agents/skills/...)
#   skills/orchestrate     ->  ~/.agents/skills/orchestrate
#   agents/codex/*.toml    ->  ~/.codex/agents/                    (or <project>/.codex/agents/)
#
# The skill text is written in Claude Code's vocabulary. For Codex the installer rewrites, and only
# rewrites: the skill invocation prefix (/orchestrate -> $orchestrate), the agent directory
# (.claude/worktrees, .claude/scratch -> .codex/...), the grill-skill names
# (mattpocock-skills:grilling -> $grilling, likewise domain-modeling) and drops the
# disable-model-invocation frontmatter line, whose Codex equivalent is the skill's agents/openai.yaml
# (allow_implicit_invocation: false), shipped in the repo.
#
# Usage:
#   ./install.sh [--target claude|codex|both|auto] [--project PATH] [--no-backup] [--ref REF]
#   curl -fsSL https://raw.githubusercontent.com/jefrykurniaone/grill-to-waves/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/jefrykurniaone/grill-to-waves.git"
SKILLS=(grill-to-waves orchestrate)
STAMP="$(date +%Y%m%d-%H%M%S)"

TARGET=""
PROJECT=""
NO_BACKUP=0
REF="main"

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:?--target needs a value}"; shift 2 ;;
    --project) PROJECT="${2:?--project needs a path}"; shift 2 ;;
    --no-backup) NO_BACKUP=1; shift ;;
    --ref) REF="${2:?--ref needs a value}"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$TARGET" in ''|claude|codex|both|auto) ;; *) echo "--target must be claude, codex, both or auto" >&2; exit 2 ;; esac

step() { printf '==> %s\n' "$1"; }
note() { printf '    %s\n' "$1"; }

select_install_target() {
  step "Choose an install target:" >&2
  note "[1] Claude Code" >&2
  note "[2] Codex CLI" >&2
  note "[3] Both" >&2

  while true; do
    printf 'Enter 1, 2 or 3: ' > /dev/tty
    IFS= read -r choice < /dev/tty || {
      echo "could not read a selection; pass --target claude, codex, both or auto" >&2
      exit 2
    }
    case "$choice" in
      1|claude) TARGET="claude"; return ;;
      2|codex) TARGET="codex"; return ;;
      3|both) TARGET="both"; return ;;
      *) note "Invalid choice. Enter 1, 2 or 3." >&2 ;;
    esac
  done
}

if [ -z "$TARGET" ]; then select_install_target; fi
step "Install target: $TARGET"

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
[ -d "$SRC/agents/codex" ] || { echo "Source tree is incomplete: $SRC/agents/codex is missing." >&2; exit 1; }

# --- 2. Decide the targets ----------------------------------------------------------------------
PROJECT_ROOT=""
if [ -n "$PROJECT" ]; then
  [ -d "$PROJECT" ] || { echo "--project path does not exist: $PROJECT. Point it at an existing repository." >&2; exit 2; }
  PROJECT_ROOT="$(cd "$PROJECT" && pwd)"
fi
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

DO_CLAUDE=0
DO_CODEX=0
case "$TARGET" in
  claude) DO_CLAUDE=1 ;;
  codex)  DO_CODEX=1 ;;
  both)   DO_CLAUDE=1; DO_CODEX=1 ;;
  auto)   DO_CLAUDE=1; [ -d "$CODEX_HOME" ] && DO_CODEX=1 || true ;;
esac

# Claude Code paths.
if [ -n "$PROJECT_ROOT" ]; then CLAUDE_HOME="$PROJECT_ROOT/.claude"; else CLAUDE_HOME="$HOME/.claude"; fi
# Codex paths: skills follow the agent-skills standard (~/.agents/skills, <repo>/.agents/skills);
# custom agents live under the Codex home (~/.codex/agents) or the project's .codex/agents.
if [ -n "$PROJECT_ROOT" ]; then
  CODEX_SKILLS_ROOT="$PROJECT_ROOT/.agents/skills"
  CODEX_AGENTS_DIR="$PROJECT_ROOT/.codex/agents"
else
  CODEX_SKILLS_ROOT="$HOME/.agents/skills"
  CODEX_AGENTS_DIR="$CODEX_HOME/agents"
fi
CODEX_BACKUPS="$CODEX_HOME/backups"

# --- 3. Helpers ---------------------------------------------------------------------------------
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

install_file() {          # $1 from, $2 to, $3 backup root
  local from="$1" to="$2" backup_root="$3"
  if [ -f "$to" ] && [ "$NO_BACKUP" != 1 ]; then
    mkdir -p "$backup_root"
    cp "$to" "$backup_root/$(basename "$to")-$STAMP"
  fi
  mkdir -p "$(dirname "$to")"
  cp "$from" "$to"
}

# Rewrite one installed skill file from Claude Code's vocabulary to Codex's. LC_ALL=C keeps sed
# byte-oriented, so non-ASCII prose passes through untouched. The first substitution runs twice
# because it consumes the character before a match and two mentions can sit close together.
codexify_skill_file() {   # $1 file
  local f="$1" tmp="$1.codex.$$"
  LC_ALL=C sed -E \
    -e 's#(^|[^[:alnum:]_./\\-])/(orchestrate|grill-to-waves)([^[:alnum:]_/-]|$)#\1$\2\3#g' \
    -e 's#(^|[^[:alnum:]_./\\-])/(orchestrate|grill-to-waves)([^[:alnum:]_/-]|$)#\1$\2\3#g' \
    -e 's#\.claude([/\\])(worktrees|scratch)#.codex\1\2#g' \
    -e 's#mattpocock-skills:grilling#$grilling#g' \
    -e 's#mattpocock-skills:domain-modeling#$domain-modeling#g' \
    -e '/^disable-model-invocation: true[[:space:]]*$/d' \
    "$f" > "$tmp"
  mv "$tmp" "$f"
}

# --- 4. Claude Code -----------------------------------------------------------------------------
if [ "$DO_CLAUDE" = 1 ]; then
  step "Claude Code -> $CLAUDE_HOME"
  for skill in "${SKILLS[@]}"; do
    install_dir "$SRC/skills/$skill" "$CLAUDE_HOME/skills/$skill" "$CLAUDE_HOME/backups"
  done
  count=0
  for agent in "$SRC"/agents/*.md; do
    install_file "$agent" "$CLAUDE_HOME/agents/$(basename "$agent")" "$CLAUDE_HOME/backups"
    count=$((count + 1))
  done
  note "installed $count agent definitions into $CLAUDE_HOME/agents"
fi

# --- 5. Codex CLI -------------------------------------------------------------------------------
if [ "$DO_CODEX" = 1 ]; then
  step "Codex CLI -> skills in $CODEX_SKILLS_ROOT, agents in $CODEX_AGENTS_DIR"
  for skill in "${SKILLS[@]}"; do
    dest="$CODEX_SKILLS_ROOT/$skill"
    install_dir "$SRC/skills/$skill" "$dest" "$CODEX_BACKUPS"
    for f in "$dest"/*.md; do codexify_skill_file "$f"; done
    note "rewrote $skill for Codex (\$-mentions, .codex/ paths, \$grilling / \$domain-modeling)"
  done

  count=0
  for agent in "$SRC"/agents/codex/*.toml; do
    install_file "$agent" "$CODEX_AGENTS_DIR/$(basename "$agent")" "$CODEX_BACKUPS"
    count=$((count + 1))
  done
  note "installed $count custom agent definitions into $CODEX_AGENTS_DIR"

  # A copy under the legacy root would register a second skill with the same name.
  for skill in "${SKILLS[@]}"; do
    if [ -e "$CODEX_HOME/skills/$skill" ]; then
      note "WARNING: $CODEX_HOME/skills/$skill also exists. ~/.codex/skills is Codex's legacy root; remove that copy or both will be listed."
    fi
  done

  # Multi-agent tools are on by default; say so if the user's config turns them off.
  config="$CODEX_HOME/config.toml"
  if [ -f "$config" ]; then
    if grep -Eq '^[[:space:]]*\[agents\]' "$config" && grep -Eq '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*false' "$config"; then
      note "WARNING: [agents] enabled = false in $config. \$orchestrate needs spawn_agent; set it to true."
    fi
    ceiling="$(sed -nE 's/^[[:space:]]*max_concurrent_threads_per_session[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' "$config" | head -n 1)"
    if [ -n "$ceiling" ]; then
      note "agents.max_concurrent_threads_per_session = $ceiling; the map's in-flight ceiling must not exceed it."
    fi
  fi
fi

# --- 6. Report ----------------------------------------------------------------------------------
step "Done."
[ "$DO_CLAUDE" = 1 ] && note "Claude Code: restart the session, then run  /grill-to-waves  and later  /orchestrate"
[ "$DO_CODEX" = 1 ] && note "Codex CLI: restart Codex, then run  \$grill-to-waves  and later  \$orchestrate"
[ "$DO_CODEX" = 1 ] && note "Codex dispatches executors with spawn_agent; the custom agents pin model and reasoning effort per tier."

# The pipeline calls grilling and domain-modeling (Stage 1) and, on Claude Code, setup-matt-pocock-skills (Stage 0).
if [ "$DO_CLAUDE" = 1 ]; then
  if compgen -G "$HOME/.claude/plugins/cache/mattpocock*" > /dev/null; then
    note "Claude Code required plugin mattpocock-skills: found."
  else
    echo ""
    step "Claude Code required plugin missing: mattpocock-skills"
    note "Stage 1 needs grilling and domain-modeling; Stage 0 suggests setup-matt-pocock-skills."
    note "In Claude Code, run:"
    note "  /plugin marketplace add mattpocock/skills"
    note "  /plugin install mattpocock-skills@mattpocock"
    note "The marketplace is named mattpocock, not skills. Restart the session afterwards."
  fi
fi
if [ "$DO_CODEX" = 1 ]; then
  missing=""
  for s in grilling domain-modeling; do
    if [ ! -f "$CODEX_SKILLS_ROOT/$s/SKILL.md" ] && [ ! -f "$HOME/.agents/skills/$s/SKILL.md" ]; then
      missing="$missing $s"
    fi
  done
  if [ -z "$missing" ]; then
    note "Codex required skills grilling and domain-modeling: found."
  else
    echo ""
    step "Codex required skills missing:$missing"
    note "Stage 1 needs \$grilling and \$domain-modeling. Copy them from https://github.com/mattpocock/skills"
    note "(the skills/grilling and skills/domain-modeling folders) into $CODEX_SKILLS_ROOT, then restart Codex."
  fi
fi
