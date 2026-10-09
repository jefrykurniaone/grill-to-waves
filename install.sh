#!/usr/bin/env bash
# Install the grill-to-waves, orchestrate, ship-it-to, daily-recap and jira-comment skills and their
# executor/scout/scribe agents for Claude Code and/or Codex CLI.
#
# Claude Code:
#   skills/grill-to-waves  ->  ~/.claude/skills/grill-to-waves     (or <project>/.claude/skills/...)
#   skills/orchestrate     ->  ~/.claude/skills/orchestrate
#   skills/ship-it-to      ->  ~/.claude/skills/ship-it-to
#   skills/daily-recap     ->  ~/.claude/skills/daily-recap
#   skills/jira-comment    ->  ~/.claude/skills/jira-comment
#   agents/*.md            ->  ~/.claude/agents/
#   statusline/statusline.js   ->  ~/.claude/statusline.js                  (always user scope)
#   "attribution": { "commit": "", "pr": "" }  ->  ~/.claude/settings.json   (always user scope;
#                             an existing attribution key is kept, and so is an existing statusLine)
#
# Codex CLI:
#   skills/grill-to-waves  ->  ~/.agents/skills/grill-to-waves     (or <project>/.agents/skills/...)
#   skills/orchestrate     ->  ~/.agents/skills/orchestrate
#   skills/ship-it-to      ->  ~/.agents/skills/ship-it-to
#   skills/daily-recap     ->  ~/.agents/skills/daily-recap
#   skills/jira-comment    ->  ~/.agents/skills/jira-comment
#   agents/codex/*.toml    ->  ~/.codex/agents/                    (or <project>/.codex/agents/)
#
# Both hosts, into the same skills directory as above:
#   github.com/mattpocock/skills, cloned at its latest release  ->  one folder per skill that
#   release ships (its .claude-plugin/plugin.json), minus --mattpocock-exclude
#
# The skill text is written in Claude Code's vocabulary. For Codex the installer rewrites, and only
# rewrites: the skill invocation prefix (/orchestrate -> $orchestrate, including the setup skill
# and the two grill skills), the agent directory (.claude/worktrees, .claude/scratch -> .codex/...)
# and drops the disable-model-invocation frontmatter line, whose Codex equivalent is the skill's
# agents/openai.yaml (allow_implicit_invocation: false), shipped in the repo.
#
# --status installs nothing. From a local checkout it lists every skill folder and agent file the
# installer would install for the chosen target as identical, differs or not installed, comparing
# byte for byte against what an install would write (for Codex, the rewritten skill text). It reads
# no network and writes no file, leaves the Matt Pocock collection out, and exits 0 whatever it
# finds: a copy that differs may be a private variant kept on purpose.
#
# Usage:
#   ./install.sh [--target claude|codex|both|auto] [--project PATH] [--no-backup] [--ref REF]
#                [--skip-mattpocock] [--mattpocock-exclude "NAME NAME"] [--status]
#   curl -fsSL https://raw.githubusercontent.com/jefrykurniaone/grill-to-waves/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/jefrykurniaone/grill-to-waves.git"
SKILLS=(grill-to-waves orchestrate ship-it-to daily-recap jira-comment)
REQUIRED_MATTPOCOCK_SKILLS=(grilling domain-modeling setup-matt-pocock-skills)
# Agent definitions this repo used to ship and no longer does. A copy left in the agent directory
# would keep registering a tier the skills no longer dispatch, so the installer removes it.
RETIRED_AGENTS=(executor-fable-five-one-medium executor-fable-five-one-high executor-fable-five-one-xhigh)
MATTPOCOCK_REPO="mattpocock/skills"
STAMP="$(date +%Y%m%d-%H%M%S)"

TARGET=""
PROJECT=""
NO_BACKUP=0
REF="main"
SKIP_MATTPOCOCK=0
# Matt Pocock skills left out of the install. `pr` dictates a pull request body template, and this
# pipeline leaves the body to the repository's own convention.
MATTPOCOCK_EXCLUDE="pr"
# Install nothing: report how the installed copies relate to this checkout. Read-only, offline.
STATUS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:?--target needs a value}"; shift 2 ;;
    --project) PROJECT="${2:?--project needs a path}"; shift 2 ;;
    --no-backup) NO_BACKUP=1; shift ;;
    --ref) REF="${2:?--ref needs a value}"; shift 2 ;;
    --skip-mattpocock) SKIP_MATTPOCOCK=1; shift ;;
    --mattpocock-exclude) [ $# -ge 2 ] || { echo "--mattpocock-exclude needs a value" >&2; exit 2; }
                          MATTPOCOCK_EXCLUDE="${2//,/ }"; shift 2 ;;
    --status) STATUS=1; shift ;;
    -h|--help) sed -n '2,43p' "$0"; exit 0 ;;
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
  [ "$STATUS" = 0 ] || { echo "--status compares the installed copies against a local checkout. Run it from a clone." >&2; exit 2; }
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
# A destination that is a symlink - an `npx skills` install links <agent>/skills/<name> to
# ~/.agents/skills/<name> - is unlinked, never followed: a recursive delete through it would empty
# the link's target.
install_dir() {           # $1 from, $2 to, $3 backup root
  local from="$1" to="$2" backup_root="$3"
  if [ -L "$to" ]; then
    rm "$to"
    note "unlinked $to"
  fi
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

# The latest release of the Matt Pocock collection: the tag GitHub names as latest, or the highest
# plain vX.Y.Z tag when the API cannot be reached (it rate-limits unauthenticated callers).
mattpocock_release_tag() {
  local tag=""
  if command -v curl >/dev/null 2>&1; then
    tag="$(curl -fsSL "https://api.github.com/repos/$MATTPOCOCK_REPO/releases/latest" 2>/dev/null \
      | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)" || true
  fi
  if [ -z "$tag" ]; then
    tag="$(git ls-remote --tags --refs "https://github.com/$MATTPOCOCK_REPO.git" 'v*' 2>/dev/null \
      | sed -n 's#.*refs/tags/\(v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$#\1#p' \
      | sort -t. -k1.2,1n -k2,2n -k3,3n | tail -n 1)" || true
  fi
  printf '%s' "$tag"
}

# Install the fetched Matt Pocock skills into one skills root. install_dir unlinks a destination
# that is a link, which is what an `npx skills` install leaves there.
install_mattpocock_skills() {   # $1 skills root, $2 backup root
  local root="$1" backup_root="$2" src
  for src in "${MATTPOCOCK_SKILL_DIRS[@]}"; do
    install_dir "$src" "$root/$(basename "$src")" "$backup_root"
  done
  note "installed ${#MATTPOCOCK_SKILL_DIRS[@]} Matt Pocock skills ($MATTPOCOCK_TAG) into $root"
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

retire_agents() {         # $1 agents dir, $2 extension, $3 backup root
  local dir="$1" ext="$2" backup_root="$3" name path
  for name in "${RETIRED_AGENTS[@]}"; do
    path="$dir/$name.$ext"
    [ -f "$path" ] || continue
    if [ "$NO_BACKUP" != 1 ]; then
      mkdir -p "$backup_root"
      cp "$path" "$backup_root/$name.$ext-$STAMP"
    fi
    rm -f "$path"
    note "removed retired agent $path"
  done
}

# Claude Code writes a Co-Authored-By trailer into every commit and a "Generated with Claude Code"
# line into every pull request body unless `attribution` hides them. The key goes in as text right
# after the opening brace, so the rest of settings.json keeps its formatting; an existing
# `attribution` is the user's own choice and is left alone.
add_claude_setting() {   # $1 settings file, $2 backup root, $3 key, $4 entry, $5 subject
  local f="$1" backup_root="$2" key="$3" entry="$4" subject="$5" tmp="$1.$3.$$" empty=0
  if [ ! -f "$f" ] || ! grep -q '[^[:space:]]' "$f"; then
    mkdir -p "$(dirname "$f")"
    printf '{\n  %s\n}\n' "$entry" > "$f"
    note "created $f with $subject"
    return
  fi
  if grep -q "\"$key\"[[:space:]]*:" "$f"; then
    note "kept the existing $key setting in $f"
    return
  fi
  case "$(tr -d '[:space:]' < "$f")" in
    '{}') empty=1 ;;
    '{'*) ;;
    *) note "WARNING: $f is not a JSON object; add $entry to it yourself."; return ;;
  esac

  LC_ALL=C awk -v entry="$entry" -v empty="$empty" '
    !done && (i = index($0, "{")) {
      print substr($0, 1, i)
      print "  " entry (empty ? "" : ",")
      rest = substr($0, i + 1)
      if (rest ~ /[^[:space:]]/) print rest
      done = 1
      next
    }
    { print }
  ' "$f" > "$tmp"

  # Validate with whichever JSON parser actually runs (on Windows, `python3` can be the Microsoft
  # Store stub, which exists but fails); without one, the insertion stands on its own.
  local valid=1
  if python3 -c 'pass' >/dev/null 2>&1; then
    python3 -c 'import json, sys; sys.exit(sys.argv[2] not in json.load(open(sys.argv[1])))' "$tmp" "$key" 2>/dev/null || valid=0
  elif node -e '' >/dev/null 2>&1; then
    node -e 'const o = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); process.exit(o[process.argv[2]] === undefined ? 1 : 0)' "$tmp" "$key" 2>/dev/null || valid=0
  fi
  if [ "$valid" != 1 ]; then
    rm -f "$tmp"
    note "WARNING: could not add $key to $f safely; add $entry to it yourself."
    return
  fi

  if [ "$NO_BACKUP" != 1 ]; then
    mkdir -p "$backup_root"
    cp "$f" "$backup_root/settings.json-$STAMP"
  fi
  mv "$tmp" "$f"
  note "added $subject to $f"
}

hide_claude_attribution() {   # $1 settings file, $2 backup root
  add_claude_setting "$1" "$2" attribution '"attribution": { "commit": "", "pr": "" }' \
    'the attribution setting (no commit or pull request attribution)'
}

# The statusline renders  model | ctx% | 5h | 7d  from the hook JSON. The script is installed
# alongside the setting that points at it, and an existing statusLine is left alone.
install_claude_statusline() {   # $1 source file, $2 user ~/.claude, $3 backup root
  local src="$1" home_dir="$2" backup_root="$3" dest="$2/statusline.js"
  install_file "$src" "$dest" "$backup_root"
  note "installed $dest"
  if ! node -e '' >/dev/null 2>&1; then
    note "WARNING: node was not found on PATH; $dest is installed but settings.json is untouched."
    return
  fi
  add_claude_setting "$home_dir/settings.json" "$backup_root" statusLine \
    "\"statusLine\": { \"type\": \"command\", \"command\": \"node '$dest'\" }" 'the statusline'
}

# Rewrite skill text on stdin from Claude Code's vocabulary to Codex's. LC_ALL=C keeps sed
# byte-oriented, so non-ASCII prose passes through untouched. The first substitution runs twice
# because it consumes the character before a match and two mentions can sit close together.
codexify_skill_text() {
  LC_ALL=C sed -E \
    -e 's#(^|[^[:alnum:]_./\\-])/(orchestrate|grill-to-waves|ship-it-to|daily-recap|jira-comment|setup-matt-pocock-skills|grilling|domain-modeling)([^[:alnum:]_/-]|$)#\1$\2\3#g' \
    -e 's#(^|[^[:alnum:]_./\\-])/(orchestrate|grill-to-waves|ship-it-to|daily-recap|jira-comment|setup-matt-pocock-skills|grilling|domain-modeling)([^[:alnum:]_/-]|$)#\1$\2\3#g' \
    -e 's#\.claude([/\\])(worktrees|scratch)#.codex\1\2#g' \
    -e '/^disable-model-invocation: true[[:space:]]*$/d'
}

# Rewrite one installed skill file for Codex.
codexify_skill_file() {   # $1 file
  local f="$1" tmp="$1.codex.$$"
  codexify_skill_text < "$f" > "$tmp"
  mv "$tmp" "$f"
}

# Print identical, not installed, or differs with the files that are changed, missing or extra.
# Codex rewrites the Markdown at the top of a skill folder and nothing below it.
dir_status() {            # $1 from, $2 to, $3 "codex" to compare against the rewritten text
  local from="$1" to="$2" mode="${3:-}" file same changed=""
  [ -d "$to" ] || { printf 'not installed'; return; }
  while IFS= read -r file; do
    same=1
    if [ ! -f "$from/$file" ] || [ ! -f "$to/$file" ]; then
      same=0
    elif [ "$mode" = codex ] && [ "${file#*/}" = "$file" ] && [ "${file%.md}" != "$file" ]; then
      codexify_skill_text < "$from/$file" | cmp -s - "$to/$file" || same=0
    else
      cmp -s "$from/$file" "$to/$file" || same=0
    fi
    [ "$same" = 1 ] || changed="${changed:+$changed, }$file"
  done < <({ (cd "$from" && find . -type f); (cd "$to" && find . -type f); } | sed 's#^\./##' | LC_ALL=C sort -u)
  if [ -z "$changed" ]; then printf 'identical'; else printf 'differs (%s)' "$changed"; fi
}

file_status() {           # $1 from, $2 to
  if [ ! -f "$2" ]; then printf 'not installed'
  elif cmp -s "$1" "$2"; then printf 'identical'
  else printf 'differs'
  fi
}

# One status line: the state in a fixed column, then the item, then the files behind a `differs`.
STATUS_IDENTICAL=0
STATUS_DIFFERS=0
STATUS_NOT_INSTALLED=0
report_status() {         # $1 state, $2 item
  local state="$1" detail=""
  case "$state" in
    identical) STATUS_IDENTICAL=$((STATUS_IDENTICAL + 1)) ;;
    'not installed') STATUS_NOT_INSTALLED=$((STATUS_NOT_INSTALLED + 1)) ;;
    differs*) STATUS_DIFFERS=$((STATUS_DIFFERS + 1))
              [ "$state" = differs ] || detail="  ${state#differs }"
              state="differs" ;;
  esac
  note "$(printf '%-13s  %s%s' "$state" "$2" "$detail")"
}

sorted_files() {          # $1 directory, $2 extension; prints the file names, one per line
  local path
  for path in "$1"/*."$2"; do
    if [ -f "$path" ]; then basename "$path"; fi
  done | LC_ALL=C sort
}

# --- 4. Status ----------------------------------------------------------------------------------
# Compare, report and stop. Nothing below this section runs, so nothing is fetched or written.
if [ "$STATUS" = 1 ]; then
  if [ "$DO_CLAUDE" = 1 ]; then
    step "Status: Claude Code -> $CLAUDE_HOME"
    for skill in "${SKILLS[@]}"; do
      report_status "$(dir_status "$SRC/skills/$skill" "$CLAUDE_HOME/skills/$skill")" "skills/$skill"
    done
    while IFS= read -r agent; do
      report_status "$(file_status "$SRC/agents/$agent" "$CLAUDE_HOME/agents/$agent")" "agents/$agent"
    done < <(sorted_files "$SRC/agents" md)
  fi
  if [ "$DO_CODEX" = 1 ]; then
    step "Status: Codex CLI -> skills in $CODEX_SKILLS_ROOT, agents in $CODEX_AGENTS_DIR"
    for skill in "${SKILLS[@]}"; do
      report_status "$(dir_status "$SRC/skills/$skill" "$CODEX_SKILLS_ROOT/$skill" codex)" "skills/$skill"
    done
    while IFS= read -r agent; do
      report_status "$(file_status "$SRC/agents/codex/$agent" "$CODEX_AGENTS_DIR/$agent")" "agents/$agent"
    done < <(sorted_files "$SRC/agents/codex" toml)
  fi
  step "Status: $STATUS_IDENTICAL identical, $STATUS_DIFFERS differs, $STATUS_NOT_INSTALLED not installed."
  note "Nothing was changed. A copy that differs stays as it is until the installer runs without --status."
  exit 0
fi

# --- 5. Fetch the Matt Pocock collection --------------------------------------------------------
# Straight from its GitHub repository, at the latest release, before anything is installed - so a
# network failure stops the run with nothing half-replaced.
MATTPOCOCK_TAG=""
MATTPOCOCK_SKILL_DIRS=()
if [ "$SKIP_MATTPOCOCK" = 0 ]; then
  command -v git >/dev/null 2>&1 || { echo "git is required to fetch $MATTPOCOCK_REPO. Re-run with --skip-mattpocock to install without it." >&2; exit 1; }
  MATTPOCOCK_TAG="$(mattpocock_release_tag)"
  [ -n "$MATTPOCOCK_TAG" ] || { echo "Could not find a release of $MATTPOCOCK_REPO. Re-run with --skip-mattpocock to install without it." >&2; exit 1; }
  MATTPOCOCK_ROOT="$(mktemp -d)/mattpocock-skills"
  step "Matt Pocock skills: fetching $MATTPOCOCK_REPO at its latest release, $MATTPOCOCK_TAG"
  # Fetch the tag rather than `clone --branch`: a shallow clone of an annotated tag works, but
  # warns that the tag "is not a commit!".
  if ! { git init --quiet "$MATTPOCOCK_ROOT" \
    && git -C "$MATTPOCOCK_ROOT" fetch --quiet --depth 1 "https://github.com/$MATTPOCOCK_REPO.git" "refs/tags/$MATTPOCOCK_TAG" \
    && git -C "$MATTPOCOCK_ROOT" -c advice.detachedHead=false checkout --quiet FETCH_HEAD; }; then
    echo "Fetching $MATTPOCOCK_REPO $MATTPOCOCK_TAG failed. Re-run with --skip-mattpocock to install without it." >&2
    exit 1
  fi
  # The release's own manifest names the skills it ships; its in-progress and misc buckets are not
  # in it.
  manifest="$MATTPOCOCK_ROOT/.claude-plugin/plugin.json"
  [ -f "$manifest" ] || { echo "$MATTPOCOCK_REPO $MATTPOCOCK_TAG has no .claude-plugin/plugin.json to read the skill list from." >&2; exit 1; }
  while IFS= read -r rel; do
    name="$(basename "$rel")"
    case " $MATTPOCOCK_EXCLUDE " in *" $name "*) note "left out $name"; continue ;; esac
    [ -f "$MATTPOCOCK_ROOT/$rel/SKILL.md" ] || { echo "$MATTPOCOCK_REPO $MATTPOCOCK_TAG lists $rel but ships no SKILL.md there." >&2; exit 1; }
    MATTPOCOCK_SKILL_DIRS+=("$MATTPOCOCK_ROOT/$rel")
  done < <(grep -o '"\./skills/[^"]*"' "$manifest" | tr -d '"' | sed 's#^\./##')
  [ "${#MATTPOCOCK_SKILL_DIRS[@]}" -gt 0 ] || { echo "$MATTPOCOCK_REPO $MATTPOCOCK_TAG lists no skills to install." >&2; exit 1; }
fi

# --- 6. Claude Code -----------------------------------------------------------------------------
if [ "$DO_CLAUDE" = 1 ]; then
  step "Claude Code -> $CLAUDE_HOME"
  for skill in "${SKILLS[@]}"; do
    install_dir "$SRC/skills/$skill" "$CLAUDE_HOME/skills/$skill" "$CLAUDE_HOME/backups"
  done
  [ "$SKIP_MATTPOCOCK" = 1 ] || install_mattpocock_skills "$CLAUDE_HOME/skills" "$CLAUDE_HOME/backups"
  count=0
  for agent in "$SRC"/agents/*.md; do
    install_file "$agent" "$CLAUDE_HOME/agents/$(basename "$agent")" "$CLAUDE_HOME/backups"
    count=$((count + 1))
  done
  note "installed $count agent definitions into $CLAUDE_HOME/agents"
  retire_agents "$CLAUDE_HOME/agents" md "$CLAUDE_HOME/backups"
  # User scope even with --project: attribution is a per-person preference, not a repository's.
  hide_claude_attribution "$HOME/.claude/settings.json" "$HOME/.claude/backups"
  # The statusline is a per-person preference too, and its script is read from the user's home.
  install_claude_statusline "$SRC/statusline/statusline.js" "$HOME/.claude" "$HOME/.claude/backups"
fi

# --- 7. Codex CLI -------------------------------------------------------------------------------
if [ "$DO_CODEX" = 1 ]; then
  step "Codex CLI -> skills in $CODEX_SKILLS_ROOT, agents in $CODEX_AGENTS_DIR"
  for skill in "${SKILLS[@]}"; do
    dest="$CODEX_SKILLS_ROOT/$skill"
    install_dir "$SRC/skills/$skill" "$dest" "$CODEX_BACKUPS"
    for f in "$dest"/*.md; do codexify_skill_file "$f"; done
    note "rewrote $skill for Codex (\$-mentions and .codex/ paths)"
  done
  [ "$SKIP_MATTPOCOCK" = 1 ] || install_mattpocock_skills "$CODEX_SKILLS_ROOT" "$CODEX_BACKUPS"

  count=0
  for agent in "$SRC"/agents/codex/*.toml; do
    install_file "$agent" "$CODEX_AGENTS_DIR/$(basename "$agent")" "$CODEX_BACKUPS"
    count=$((count + 1))
  done
  note "installed $count custom agent definitions into $CODEX_AGENTS_DIR"
  retire_agents "$CODEX_AGENTS_DIR" toml "$CODEX_BACKUPS"

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

# --- 8. Report ----------------------------------------------------------------------------------
step "Done."
[ "$DO_CLAUDE" = 1 ] && note "Claude Code: restart the session, then run  /grill-to-waves , later  /orchestrate , and  /ship-it-to stg|prd  to promote"
[ "$DO_CLAUDE" = 1 ] && note "Claude Code: end the day with  /daily-recap  for the team recap"
[ "$DO_CLAUDE" = 1 ] && note "Claude Code: once a fix has moved, draft its ticket comment with  /jira-comment"
[ "$DO_CODEX" = 1 ] && note "Codex CLI: restart Codex, then run  \$grill-to-waves , later  \$orchestrate , and  \$ship-it-to stg|prd  to promote"
[ "$DO_CODEX" = 1 ] && note "Codex CLI: end the day with  \$daily-recap  for the team recap"
[ "$DO_CODEX" = 1 ] && note "Codex CLI: once a fix has moved, draft its ticket comment with  \$jira-comment"
[ "$DO_CODEX" = 1 ] && note "Codex dispatches executors with spawn_agent; the custom agents pin model and reasoning effort per tier."

# The pipeline requires setup-matt-pocock-skills (Stage 0), grilling and domain-modeling (Stage 1).
if [ "$DO_CLAUDE" = 1 ]; then
  missing=""
  for s in "${REQUIRED_MATTPOCOCK_SKILLS[@]}"; do
    if [ ! -f "$CLAUDE_HOME/skills/$s/SKILL.md" ] && \
       [ ! -f "$HOME/.claude/skills/$s/SKILL.md" ] && \
       [ ! -f "$PWD/.claude/skills/$s/SKILL.md" ]; then
      missing="$missing $s"
    fi
  done
  if [ -z "$missing" ]; then
    note "Claude Code required skills found: ${REQUIRED_MATTPOCOCK_SKILLS[*]}."
  else
    echo ""
    step "Claude Code required skills missing:$missing"
    note "Stage 0 suggests /setup-matt-pocock-skills; Stage 1 needs /grilling and /domain-modeling."
    note "Re-run without --skip-mattpocock, and without excluding them, to fetch them from the latest release of $MATTPOCOCK_REPO."
  fi
  # The plugin registers every skill a second time, under a prefix the pipeline does not call.
  if grep -q '"mattpocock-skills@' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
    note "WARNING: the mattpocock-skills plugin is installed too, so each skill is listed twice. Remove it:  claude plugin uninstall mattpocock-skills@mattpocock"
  fi
fi
if [ "$DO_CODEX" = 1 ]; then
  missing=""
  for s in "${REQUIRED_MATTPOCOCK_SKILLS[@]}"; do
    if [ ! -f "$CODEX_SKILLS_ROOT/$s/SKILL.md" ] && \
       [ ! -f "$HOME/.agents/skills/$s/SKILL.md" ] && \
       [ ! -f "$PWD/.agents/skills/$s/SKILL.md" ]; then
      missing="$missing $s"
    fi
  done
  if [ -z "$missing" ]; then
    note "Codex required skills found: ${REQUIRED_MATTPOCOCK_SKILLS[*]}."
  else
    echo ""
    step "Codex required skills missing:$missing"
    note "Stage 0 needs \$setup-matt-pocock-skills; Stage 1 needs \$grilling and \$domain-modeling."
    note "Re-run without --skip-mattpocock, and without excluding them, to fetch them from the latest release of $MATTPOCOCK_REPO."
  fi
fi
