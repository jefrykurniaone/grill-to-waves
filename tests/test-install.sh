#!/usr/bin/env bash
# Tests for install.sh.
#
#   bash tests/test-install.sh
#
# Every installer run goes through tests/lib/guarded-install.sh with HOME pointed at a scratch
# directory under the system temp path, and works from a snapshot of the checkout taken when the
# script starts. The last test compares the real ~/.claude, ~/.agents and ~/.codex against a
# fingerprint taken before the first one.
#
# The parity test also runs install.ps1, so it needs pwsh. Without it the test is skipped, unless
# G2W_REQUIRE_PARITY is 1, which turns the skip into a failure.
#
# gh, glab, claude and codex are stand-ins on every run (tests/lib/stub-cli.js, started with node), so
# no test signs in to a forge or registers an MCP server for real. Without node each stand-in only
# exits 1, and the tests that read their calls are skipped.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
REAL_HOME="$HOME"
REAL_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SCRATCH_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/g2w-tests-XXXXXX")"
SOURCE="$SCRATCH_ROOT/source"
MENTION='(orchestrate|conduct|grill-to-waves|ship-it-to|daily-recap|jira-comment|setup-matt-pocock-skills|grilling|domain-modeling)'
INSTALLED_PATHS=(.claude/skills .claude/agents .claude/statusline.js .agents/skills .codex/agents)
SKIP_CODE=77
STUB_NAMES=(gh glab claude codex npx markitdown-mcp)
ALL_MCP_FLAGS=(--with-playwright-mcp --with-context7-mcp --with-markitdown-mcp)
FLATPAK_CHROME="app/com.google.Chrome/current/active/files/extra/chrome"
PLAYWRIGHT_ADD="playwright -- npx -y @playwright/mcp@latest"
LINK_BOTH=(--target both --skip-mattpocock --link)
NODE="$(command -v node || true)"
export G2W_STUB_LOG="$SCRATCH_ROOT/stub-calls.log"

PASSED=0
FAILED=0
SKIPPED=0

if command -v sha256sum >/dev/null 2>&1; then HASH=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then HASH=(shasum -a 256)
else HASH=(cksum)
fi

# --- Harness ------------------------------------------------------------------------------------
run_case() {              # $1 name, $2 function
  local log="$SCRATCH_ROOT/case.log" code
  ( set -e; "$2" ) > "$log" 2>&1
  code=$?
  if [ "$code" = 0 ]; then
    PASSED=$((PASSED + 1)); echo "PASS  $1"
  elif [ "$code" = "$SKIP_CODE" ]; then
    SKIPPED=$((SKIPPED + 1)); echo "SKIP  $1 ($(tail -n 1 "$log"))"
  else
    FAILED=$((FAILED + 1)); echo "FAIL  $1"; sed 's/^/      /' "$log"
  fi
}

fail() { printf '%s\n' "$*" >&2; exit 1; }
skip() { printf '%s\n' "$*"; exit "$SKIP_CODE"; }
contains() { printf '%s\n' "$1" | grep -qE -- "$2"; }
has_line() { printf '%s\n' "$1" | grep -qxF -- "$2"; }
count_matches() {         # $1 pattern, $2 file; prints the number of matches, not of lines
  { LC_ALL=C grep -oE -- "$1" "$2" || true; } | wc -l | tr -d ' '
}

# --- Scratch directories and installer runs -----------------------------------------------------
new_scratch_home() {      # $1 name; prints the path
  mkdir -p "$SCRATCH_ROOT/$1"
  echo "test scratch home" > "$SCRATCH_ROOT/$1/.g2w-scratch"
  printf '%s' "$SCRATCH_ROOT/$1"
}

run_installer() {         # $1 scratch home, then install.sh arguments
  local scratch="$1"
  shift
  rm -f "$G2W_STUB_LOG"
  bash "$HERE/lib/guarded-install.sh" "$scratch" "$SOURCE/install.sh" "$@" 2>&1
}

# A directory of stand-ins for the named programs, each running stub-cli.js under its own name.
# Without node each one only exits 1, which still keeps the real program from running: a real gh
# writes its state under the scratch HOME.
new_stub_dir() {          # $1 name, then the programs; prints the directory
  local dir="$SCRATCH_ROOT/$1" program
  shift
  mkdir -p "$dir"
  for program in "$@"; do
    if [ -n "$NODE" ]; then
      # shellcheck disable=SC2016  # "$@" belongs to the stand-in
      printf '#!/bin/sh\nexec "%s" "%s" %s "$@"\n' "$NODE" "$HERE/lib/stub-cli.js" "$program" > "$dir/$program"
    else
      printf '#!/bin/sh\nexit 1\n' > "$dir/$program"
    fi
    chmod +x "$dir/$program"
  done
  printf '%s' "$dir"
}

# A directory of links to everything on PATH except the named programs, earlier entries first, so a
# PATH made of it leaves those programs out and keeps bash and coreutils that share their directory.
path_without() {          # $1 directory to fill, then the programs to leave out
  local dir="$1" entry name
  shift
  mkdir -p "$dir"
  while IFS= read -r entry; do
    [ -d "$entry" ] || continue
    ln -s "$entry"/* "$dir"/ 2>/dev/null || true
  done < <(printf '%s\n' "$PATH" | tr ':' '\n')
  for name in "$@"; do rm -f "$dir/$name"; done
}

stub_calls() { if [ -f "$G2W_STUB_LOG" ]; then cat "$G2W_STUB_LOG"; fi; }

touch_path() { mkdir -p "$(dirname "$1")"; : > "$1"; }

has_pwsh() {
  command -v pwsh >/dev/null 2>&1 && return 0
  [ "${G2W_REQUIRE_PARITY:-0}" != 1 ] || fail "G2W_REQUIRE_PARITY is 1 and no pwsh was found to run install.ps1."
  return 1
}

run_ps1_installer() {     # $1 scratch home, then install.ps1 arguments
  local scratch="$1"
  shift
  HOME="$scratch" USERPROFILE="$scratch" CODEX_HOME="$scratch/.codex" \
    pwsh -NoProfile -NonInteractive -File "$HERE/lib/guarded-install.ps1" \
    -ScratchHome "$scratch" -Installer "$SOURCE/install.ps1" "$@" 2>&1
}

# --- Reading trees ------------------------------------------------------------------------------
file_map() {              # $1 directory; one line per file and link under it, in byte order
  (
    cd "$1" || exit 1
    find . -type f -exec "${HASH[@]}" {} +
    # shellcheck disable=SC2016  # $1 belongs to the inner sh
    find . -type l -exec sh -c 'printf "link  %s -> %s\n" "$1" "$(readlink "$1")"' _ {} \;
  ) | LC_ALL=C sort
}

installed_links() {
  local path
  for path in "$1"/.claude/skills/* "$1"/.claude/agents/* "$1"/.codex/agents/* "$1"/.agents/skills/* "$1/.claude/statusline.js"; do
    if [ -L "$path" ]; then printf '%s -> %s\n' "${path#"$1"/}" "$(readlink "$path")"; fi
  done | LC_ALL=C sort
}

expected_links() {
  local name
  {
    for name in "${SKILLS[@]}"; do printf '.claude/skills/%s -> %s\n' "$name" "$SOURCE/skills/$name"; done
    for name in "${CLAUDE_AGENTS[@]}"; do printf '.claude/agents/%s -> %s\n' "$name" "$SOURCE/agents/$name"; done
    printf '.claude/statusline.js -> %s\n' "$SOURCE/statusline/statusline.js"
    if [ "$1" = both ]; then
      for name in "${CODEX_AGENTS[@]}"; do printf '.codex/agents/%s -> %s\n' "$name" "$SOURCE/agents/codex/$name"; done
    fi
  } | LC_ALL=C sort
}

replaced_backups() {
  if [ -d "$1/.claude/backups" ]; then find "$1/.claude/backups" -mindepth 1 -maxdepth 1 ! -name 'settings.json-*'; fi
}

count_lines() { printf '%s\n' "$1" | grep -cE -- "$2" || true; }

status_lines() { printf '%s\n' "$1" | grep -E '^    (identical|linked|differs|not installed) {2,}[^ ]' || true; }

# Everything an install could write in the real home. find does not follow links, so a linked
# skill folder is recorded as a link. The backups are compared by entry name: the installer only
# ever adds entries there, and Claude Code keeps its own .claude.json backups in ~/.claude/backups
# while it runs.
real_home_fingerprint() {
  local path
  for path in "$REAL_HOME/.claude/skills" "$REAL_HOME/.claude/agents" "$REAL_HOME/.claude/settings.json" \
              "$REAL_HOME/.claude/statusline.js" "$REAL_HOME/.agents" "$REAL_CODEX_HOME/agents" "$REAL_CODEX_HOME/skills"; do
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then echo "missing  $path"; continue; fi
    find "$path" -type d
    find "$path" -type f -exec "${HASH[@]}" {} +
    # shellcheck disable=SC2016  # $1 belongs to the inner sh
    find "$path" -type l -exec sh -c 'printf "link  %s -> %s\n" "$1" "$(readlink "$1")"' _ {} \;
  done | LC_ALL=C sort
  for path in "$REAL_HOME/.claude/backups" "$REAL_CODEX_HOME/backups"; do
    if [ ! -d "$path" ]; then echo "missing  $path"; continue; fi
    find "$path" -mindepth 1 -maxdepth 1 ! -name '.claude.json*' | LC_ALL=C sort
  done
}

# --- Tests --------------------------------------------------------------------------------------
case_guard() {
  local unmarked="$SCRATCH_ROOT/unmarked" out code=0
  mkdir -p "$unmarked"
  out="$(run_installer "$unmarked" --target both --skip-mattpocock)" || code=$?
  [ "$code" != 0 ] || fail "the guard let an unmarked directory through"
  contains "$out" 'Refusing to run the installer' || fail "unexpected output: $out"
  [ -z "$(ls -A "$unmarked")" ] || fail "the unmarked directory was written to"
}

case_end_to_end() {
  local scratch out skill file agent count unexpected
  scratch="$(new_scratch_home e2e)"
  # A retired agent left by an earlier release has to go.
  mkdir -p "$scratch/.claude/agents" "$scratch/.codex/agents"
  echo retired > "$scratch/.claude/agents/executor-fable-five-one-high.md"
  echo retired > "$scratch/.codex/agents/executor-fable-five-one-high.toml"
  echo retired > "$scratch/.claude/agents/scout-sonnet-medium.md"
  echo retired > "$scratch/.codex/agents/scout-sonnet-medium.toml"

  out="$(run_installer "$scratch" --target both --skip-mattpocock)" || fail "install.sh --target both exited $?: $out"
  contains "$out" '^==> Done\.$' || fail "no Done line: $out"
  [ "${#SKILLS[@]}" -ge 5 ] || fail "expected at least 5 skills in the checkout, found ${#SKILLS[@]}"

  for skill in "${SKILLS[@]}"; do
    diff -r "$SOURCE/skills/$skill" "$scratch/.claude/skills/$skill" || fail "Claude Code copy of $skill is not the checkout's"
    diff <(cd "$SOURCE/skills/$skill" && find . -type f | LC_ALL=C sort) \
         <(cd "$scratch/.agents/skills/$skill" && find . -type f | LC_ALL=C sort) || fail "Codex copy of $skill has different files"
    # Codex rewrites only the Markdown at the top of the skill folder.
    while IFS= read -r file; do
      case "$file" in ./*/*) ;; *.md) continue ;; esac
      cmp "$SOURCE/skills/$skill/$file" "$scratch/.agents/skills/$skill/$file" || fail "Codex copy of $skill differs outside its top-level Markdown"
    done < <(cd "$SOURCE/skills/$skill" && find . -type f)
  done

  count=0
  for agent in "$SOURCE"/agents/*.md; do
    cmp "$agent" "$scratch/.claude/agents/$(basename "$agent")" || fail "Claude Code agent $(basename "$agent") is not the checkout's"
    count=$((count + 1))
  done
  [ "$(find "$scratch/.claude/agents" -type f | wc -l | tr -d ' ')" = "$count" ] || fail "Claude Code agents directory holds more than the checkout's agents"
  diff -r "$SOURCE/agents/codex" "$scratch/.codex/agents" || fail "Codex agents are not the checkout's"
  cmp "$SOURCE/statusline/statusline.js" "$scratch/.claude/statusline.js" || fail "statusline.js is not the checkout's"

  grep -qF '"attribution": { "commit": "", "pr": "" }' "$scratch/.claude/settings.json" || fail "settings.json has no attribution setting"
  if node -e '' >/dev/null 2>&1; then
    grep -q '"statusLine".*statusline\.js' "$scratch/.claude/settings.json" || fail "settings.json has no statusLine although node runs"
    node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$scratch/.claude/settings.json" || fail "settings.json is not valid JSON"
  fi

  [ ! -e "$scratch/.claude/agents/executor-fable-five-one-high.md" ] || fail "retired Claude Code agent was kept"
  [ ! -e "$scratch/.codex/agents/executor-fable-five-one-high.toml" ] || fail "retired Codex agent was kept"
  [ ! -e "$scratch/.claude/agents/scout-sonnet-medium.md" ] || fail "retired Claude Code scout was kept"
  [ ! -e "$scratch/.codex/agents/scout-sonnet-medium.toml" ] || fail "retired Codex scout was kept"
  [ "$(find "$scratch/.claude/backups" -name 'executor-fable-five-one-high.md-*' | wc -l | tr -d ' ')" = 1 ] || fail "retired Claude Code agent was not backed up"

  unexpected="$(find "$scratch" -mindepth 1 -maxdepth 1 ! -name .g2w-scratch ! -name .claude ! -name .agents ! -name .codex)"
  [ -z "$unexpected" ] || fail "the install wrote outside .claude, .agents and .codex: $unexpected"
}

case_reinstall() {
  local scratch out private kept
  scratch="$(new_scratch_home reinstall)"
  out="$(run_installer "$scratch" --target claude --skip-mattpocock)" || fail "first install exited $?: $out"
  private="$scratch/.claude/skills/orchestrate/PRIVATE.md"
  echo "a private note" > "$private"
  out="$(run_installer "$scratch" --target claude --skip-mattpocock)" || fail "second install exited $?: $out"
  contains "$out" 'backed up existing copy' || fail "no backup note: $out"
  [ ! -e "$private" ] || fail "the replaced copy was merged into, not replaced"
  kept="$(find "$scratch/.claude/backups" -mindepth 1 -maxdepth 1 -type d -name 'orchestrate-*')"
  [ -d "$kept" ] || fail "expected one backup of orchestrate, found: $kept"
  [ -f "$kept/PRIVATE.md" ] || fail "the backup lost the private file"
}

case_project() {
  local scratch project="$SCRATCH_ROOT/project-repo" out path
  scratch="$(new_scratch_home project-home)"
  mkdir -p "$project"
  out="$(run_installer "$scratch" --target both --skip-mattpocock --project "$project")" || fail "install.sh --project exited $?: $out"
  for path in .claude/skills/orchestrate/SKILL.md .agents/skills/orchestrate/SKILL.md \
              ".claude/agents/${CLAUDE_AGENTS[0]}" ".codex/agents/${CODEX_AGENTS[0]}"; do
    [ -f "$project/$path" ] || fail "missing in the project: $path"
  done
  for path in .claude/settings.json .claude/statusline.js; do
    [ -f "$scratch/$path" ] || fail "missing in the home: $path"
  done
  for path in .claude/skills .claude/agents .agents .codex; do
    [ ! -e "$scratch/$path" ] || fail "written to the home despite --project: $path"
  done
}

case_codex_conversion() {
  local scratch out skill file label from to mentions directories dropped
  local slash dollar segment claude_dir codex_dir frontmatter total_slash=0 total_directory=0 total_frontmatter=0
  scratch="$(new_scratch_home codex)"
  out="$(run_installer "$scratch" --target codex --skip-mattpocock)" || fail "install.sh --target codex exited $?: $out"
  slash='(^|[[:space:]`(*])/'"$MENTION"'($|[[:space:]`).,;:*])'
  dollar='[$]'"$MENTION"
  segment='[[:alnum:]_.]/'"$MENTION"
  claude_dir='\.claude[/\\](worktrees|scratch)'
  codex_dir='\.codex[/\\](worktrees|scratch)'
  frontmatter='^disable-model-invocation: true[[:space:]]*$'

  for skill in "${SKILLS[@]}"; do
    for from in "$SOURCE/skills/$skill"/*.md; do
      file="$(basename "$from")"
      label="$skill/$file"
      to="$scratch/.agents/skills/$skill/$file"
      [ "$(head -c 3 "$to" | od -An -tx1 | tr -d ' \n')" != efbbbf ] || fail "$label gained a BOM"

      mentions="$(count_matches "$slash" "$from")"
      directories="$(count_matches "$claude_dir" "$from")"
      dropped="$({ LC_ALL=C grep -E -- "$frontmatter" "$from" || true; } | wc -c | tr -d ' ')"
      total_slash=$((total_slash + mentions))
      total_directory=$((total_directory + directories))
      [ "$dropped" = 0 ] || total_frontmatter=$((total_frontmatter + 1))

      [ "$(count_matches "$slash" "$to")" = 0 ] || fail "$label still has slash mentions"
      [ $(( $(count_matches "$dollar" "$to") - $(count_matches "$dollar" "$from") )) -ge "$mentions" ] || fail "$label gained fewer \$ mentions than it had slash mentions"
      [ "$(count_matches "$claude_dir" "$to")" = 0 ] || fail "$label still names .claude/worktrees or .claude/scratch"
      [ "$(count_matches "$codex_dir" "$to")" = $((directories + $(count_matches "$codex_dir" "$from"))) ] || fail "$label has the wrong number of .codex/ paths"
      [ "$(count_matches '^disable-model-invocation:' "$to")" = 0 ] || fail "$label kept the disable-model-invocation line"
      [ "$(count_matches "$segment" "$to")" = "$(count_matches "$segment" "$from")" ] || fail "$label had a path segment rewritten"
      [ "$(LC_ALL=C tr -d '\000-\177' < "$to" | wc -c | tr -d ' ')" = "$(LC_ALL=C tr -d '\000-\177' < "$from" | wc -c | tr -d ' ')" ] \
        || fail "$label lost or gained non-ASCII bytes"
      # /name -> $name keeps the length, .claude -> .codex drops one byte, and the frontmatter
      # line goes whole. Any other edit breaks this sum.
      [ "$(wc -c < "$to" | tr -d ' ')" = $(( $(wc -c < "$from" | tr -d ' ') - directories - dropped )) ] \
        || fail "$label changed by more than the three rewrites"
    done
  done
  [ "$total_slash" -gt 0 ] || fail "no skill in the checkout has a slash mention, so the test proves nothing"
  [ "$total_directory" -gt 0 ] || fail "no skill in the checkout names .claude/worktrees or .claude/scratch"
  [ "$total_frontmatter" -ge "${#SKILLS[@]}" ] || fail "a skill in the checkout has no disable-model-invocation line"

  to="$scratch/.agents/skills/orchestrate/SKILL.md"
  grep -qF "\$grill-to-waves" "$to" || fail "orchestrate/SKILL.md does not mention \$grill-to-waves"
  grep -qF '.codex/worktrees' "$to" || fail "orchestrate/SKILL.md does not name .codex/worktrees"
  grep -qF '../grill-to-waves/' "$to" || fail "orchestrate/SKILL.md lost its ../grill-to-waves/ links"
}

link_case() {             # $1 a name for the scratch directories, then extra install.sh arguments
  local name="$1" scratch out root target before
  shift
  scratch="$(new_scratch_home "link-$name")"
  for root in .claude/skills .agents/skills; do
    target="$SCRATCH_ROOT/link-target-$name-${root%%/*}"
    mkdir -p "$target/nested" "$scratch/$root"
    echo "keep me" > "$target/keep.txt"
    echo "keep me too" > "$target/nested/keep.txt"
    ln -s "$target" "$scratch/$root/orchestrate"
    [ -L "$scratch/$root/orchestrate" ] || fail "could not create a link at $root/orchestrate"
    file_map "$target" > "$target.before"
  done
  out="$(run_installer "$scratch" --target both --skip-mattpocock "$@")" || fail "install over a link exited $?: $out"
  for root in .claude/skills .agents/skills; do
    target="$SCRATCH_ROOT/link-target-$name-${root%%/*}"
    [ ! -L "$scratch/$root/orchestrate" ] || fail "$root/orchestrate is still a link"
    [ -f "$scratch/$root/orchestrate/SKILL.md" ] || fail "$root/orchestrate has no SKILL.md"
    [ ! -e "$scratch/$root/orchestrate/keep.txt" ] || fail "$root/orchestrate was installed into the link's target"
    before="$(cat "$target.before")"
    [ "$before" = "$(file_map "$target")" ] || fail "the target of $root/orchestrate was changed through the link"
  done
  [ "$(printf '%s\n' "$out" | grep -c '^    unlinked ')" = 2 ] || fail "expected two unlinked notes: $out"
}
case_link_backup() { link_case backup; }
case_link_no_backup() { link_case no-backup --no-backup; }

case_status() {
  local scratch out lines installed changed claude codex
  scratch="$(new_scratch_home status)"
  out="$(run_installer "$scratch" --status --target both)" || fail "--status on an empty home exited $?: $out"
  lines="$(status_lines "$out")"
  [ "$(printf '%s\n' "$lines" | wc -l | tr -d ' ')" = "$EXPECTED_STATUS_COUNT" ] || fail "wrong number of status lines: $out"
  [ -z "$(printf '%s\n' "$lines" | grep -v '^    not installed  ' || true)" ] || fail "an empty home reported something installed: $out"
  [ "$(ls -A "$scratch")" = .g2w-scratch ] || fail "--status wrote to an empty home"
  has_line "$out" '    gh (GitHub): installed' || fail "gh not reported as installed: $out"
  has_line "$out" '    glab (GitLab): installed' || fail "glab not reported as installed: $out"
  [ -z "$(stub_calls)" ] || fail "--status ran a forge CLI, so it did not stay offline: $(stub_calls)"

  out="$(run_installer "$scratch" --target both --skip-mattpocock)" || fail "install before --status exited $?: $out"
  installed="$(file_map "$scratch")"
  out="$(run_installer "$scratch" --status --target both)" || fail "--status after an install exited $?: $out"
  lines="$(status_lines "$out")"
  [ "$(printf '%s\n' "$lines" | wc -l | tr -d ' ')" = "$EXPECTED_STATUS_COUNT" ] || fail "wrong number of status lines: $out"
  [ -z "$(printf '%s\n' "$lines" | grep -vE '^    identical      [^ ]+$' || true)" ] || fail "a fresh install is not identical: $out"
  has_line "$out" "==> Status: $EXPECTED_STATUS_COUNT identical, 0 linked, 0 differs, 0 not installed." || fail "wrong summary: $out"
  [ "$installed" = "$(file_map "$scratch")" ] || fail "--status changed the installed tree"

  # A private variant, an extra file, a changed agent and a deleted agent.
  printf '\nA private rule.\n' >> "$scratch/.claude/skills/orchestrate/SKILL.md"
  echo extra > "$scratch/.agents/skills/ship-it-to/extra.txt"
  printf '\nchanged\n' >> "$scratch/.claude/agents/${CLAUDE_AGENTS[0]}"
  rm "$scratch/.codex/agents/${CODEX_AGENTS[0]}"
  changed="$(file_map "$scratch")"
  out="$(run_installer "$scratch" --status --target both)" || fail "--status with a private variant exited $? (differs is not an error): $out"
  claude="$(printf '%s\n' "$out" | sed '/^==> Status: Codex CLI/,$d')"
  codex="$(printf '%s\n' "$out" | sed -n '/^==> Status: Codex CLI/,$p')"
  [ -n "$codex" ] || fail "no Codex section: $out"
  has_line "$claude" '    differs        skills/orchestrate  (SKILL.md)' || fail "Claude Code orchestrate not reported as differs: $out"
  has_line "$claude" "    differs        agents/${CLAUDE_AGENTS[0]}" || fail "changed agent not reported as differs: $out"
  has_line "$codex" '    differs        skills/ship-it-to  (extra.txt)' || fail "Codex ship-it-to not reported as differs: $out"
  has_line "$codex" "    not installed  agents/${CODEX_AGENTS[0]}" || fail "deleted agent not reported as not installed: $out"
  has_line "$out" "==> Status: $((EXPECTED_STATUS_COUNT - 4)) identical, 0 linked, 3 differs, 1 not installed." || fail "wrong summary: $out"
  [ "$changed" = "$(file_map "$scratch")" ] || fail "--status changed a tree that differs"
}

case_forge_and_mcp() {
  local scratch stubs out expected line markitdown
  [ -n "$NODE" ] || skip "no node found to run the CLI stand-ins"
  scratch="$(new_scratch_home mcp)"
  stubs="$(new_stub_dir stubs-all "${STUB_NAMES[@]}")"
  export PATH="$stubs:$PATH" G2W_STUB_SIGNED_IN=gh G2W_STUB_CLAUDE_SERVERS=playwright G2W_STUB_CODEX_SERVERS=markitdown

  out="$(run_installer "$scratch" --target both --skip-mattpocock)" || fail "install without an MCP flag exited $?: $out"
  [ "$(stub_calls)" = "$(printf 'gh auth status\nglab auth status')" ] || fail "an install without an MCP flag ran more than the sign-in checks: $(stub_calls)"
  has_line "$out" '    gh (GitHub): signed in' || fail "gh not reported as signed in: $out"
  has_line "$out" '    glab (GitLab): installed, not signed in - run  glab auth login' || fail "glab not reported as signed out: $out"
  if contains "$out" 'neither gh nor glab'; then fail "warned about missing forge CLIs: $out"; fi

  out="$(run_installer "$scratch" --target both --skip-mattpocock "${ALL_MCP_FLAGS[@]}")" || fail "install with every MCP flag exited $?: $out"
  markitdown="$stubs/markitdown-mcp"
  # Git Bash hands a path to a Windows program, node here, in C:/ form.
  if command -v cygpath >/dev/null 2>&1; then markitdown="$(cygpath -m "$markitdown")"; fi
  expected="$(printf '%s\n' \
    'claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest' \
    'claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp' \
    "claude mcp add --scope user markitdown -- $markitdown" \
    'codex mcp get playwright' 'codex mcp add playwright -- npx -y @playwright/mcp@latest' \
    'codex mcp get context7' 'codex mcp add context7 -- npx -y @upstash/context7-mcp' \
    'codex mcp get markitdown' 'gh auth status' 'glab auth status')"
  [ "$(stub_calls)" = "$expected" ] || fail "the installer made the wrong host CLI calls: $(stub_calls)"
  for line in \
    'kept the existing playwright MCP server for Claude Code' \
    'registered context7 for Claude Code:  claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp' \
    "registered markitdown for Claude Code:  claude mcp add --scope user markitdown -- $stubs/markitdown-mcp" \
    'registered playwright for Codex CLI:  codex mcp add playwright -- npx -y @playwright/mcp@latest' \
    'registered context7 for Codex CLI:  codex mcp add context7 -- npx -y @upstash/context7-mcp' \
    'kept the existing markitdown MCP server for Codex CLI'; do
    has_line "$out" "    $line" || fail "no line '$line': $out"
  done
}

case_forge_and_mcp_missing() {
  local scratch stubs bare out server line expected
  [ -n "$NODE" ] || skip "no node found to run the CLI stand-ins"
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) skip "ln -s copies instead of linking here" ;; esac
  scratch="$(new_scratch_home mcp-missing)"
  bare="$SCRATCH_ROOT/path-without"
  path_without "$bare" "${STUB_NAMES[@]}"

  export PATH="$bare"
  out="$(run_installer "$scratch" --target both --skip-mattpocock "${ALL_MCP_FLAGS[@]}")" || fail "install with every MCP flag and nothing on PATH exited $?: $out"
  [ -z "$(stub_calls)" ] || fail "a CLI ran although none was on PATH: $(stub_calls)"
  has_line "$out" '    gh (GitHub): not installed' || fail "gh not reported as missing: $out"
  has_line "$out" '    glab (GitLab): not installed' || fail "glab not reported as missing: $out"
  contains "$out" '^    WARNING: neither gh nor glab is installed, so the pipeline falls back to local Markdown under \.scratch/\.' \
    || fail "no warning about the missing forge CLIs: $out"
  for server in playwright context7 markitdown; do
    contains "$out" "^    WARNING: claude is not on PATH, so $server was not registered for Claude Code\. Run:  claude mcp add --scope user " \
      || fail "no warning about claude for $server: $out"
    contains "$out" "^    WARNING: codex is not on PATH, so $server was not registered for Codex CLI\. Run:  codex mcp add " \
      || fail "no warning about codex for $server: $out"
  done

  # The host CLIs are there, npx and markitdown-mcp are not, and each host already has one server.
  stubs="$(new_stub_dir stubs-hosts claude codex)"
  export PATH="$stubs:$bare" G2W_STUB_CLAUDE_SERVERS=playwright G2W_STUB_CODEX_SERVERS=context7
  out="$(run_installer "$scratch" --target both --skip-mattpocock "${ALL_MCP_FLAGS[@]}")" || fail "install with every MCP flag and no npx or markitdown-mcp exited $?: $out"
  expected="$(printf '%s\n' \
    'claude mcp get playwright' \
    'claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp' \
    'claude mcp get markitdown' 'codex mcp get playwright' 'codex mcp get context7' 'codex mcp get markitdown')"
  [ "$(stub_calls)" = "$expected" ] || fail "the installer made the wrong host CLI calls: $(stub_calls)"
  for line in \
    'kept the existing playwright MCP server for Claude Code' \
    'registered context7 for Claude Code:  claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp' \
    'WARNING: markitdown-mcp is not on PATH, so markitdown was not registered for Claude Code. Install it with  pip install markitdown-mcp , then run the installer again.' \
    'WARNING: npx is not on PATH, so playwright was not registered for Codex CLI. Install Node.js, which ships npx, then run the installer again.' \
    'kept the existing context7 MCP server for Codex CLI' \
    'WARNING: markitdown-mcp is not on PATH, so markitdown was not registered for Codex CLI. Install it with  pip install markitdown-mcp , then run the installer again.'; do
    has_line "$out" "    $line" || fail "no line '$line': $out"
  done
}

case_parity() {
  local from_sh from_ps1 out path cross_sh cross_ps1
  if ! command -v pwsh >/dev/null 2>&1; then
    [ "${G2W_REQUIRE_PARITY:-0}" != 1 ] || fail "G2W_REQUIRE_PARITY is 1 and no pwsh was found to run install.ps1."
    skip "no pwsh found to run install.ps1"
  fi
  from_sh="$(new_scratch_home parity-sh)"
  from_ps1="$(new_scratch_home parity-ps1)"
  out="$(run_installer "$from_sh" --target both --skip-mattpocock)" || fail "install.sh exited $?: $out"
  out="$(run_ps1_installer "$from_ps1" -Target both -SkipMattPocock)" || fail "install.ps1 exited $?: $out"
  for path in "${INSTALLED_PATHS[@]}"; do
    [ -e "$from_sh/$path" ] || fail "install.sh did not write $path"
    diff -r "$from_sh/$path" "$from_ps1/$path" || fail "install.sh and install.ps1 produced different trees under $path"
  done

  # Each installer's status mode agrees that the other's install is what it would write.
  cross_sh="$(run_installer "$from_ps1" --status --target both)" || fail "install.sh --status on the install.ps1 tree exited $?: $cross_sh"
  cross_ps1="$(run_ps1_installer "$from_sh" -Status -Target both)" || fail "install.ps1 -Status on the install.sh tree exited $?: $cross_ps1"
  for out in "$cross_sh" "$cross_ps1"; do
    [ "$(status_lines "$out" | wc -l | tr -d ' ')" = "$EXPECTED_STATUS_COUNT" ] || fail "wrong number of status lines: $out"
    [ -z "$(status_lines "$out" | grep -vE '^    identical      [^ ]+$' || true)" ] || fail "status across installers is not identical: $out"
  done
  [ "$(status_lines "$cross_sh")" = "$(status_lines "$cross_ps1" | tr -d '\r')" ] || fail "the two status reports differ"
}

case_link_mode_install() {
  local scratch out links source_before skill
  scratch="$(new_scratch_home link-mode)"
  source_before="$(file_map "$SOURCE")"
  out="$(run_installer "$scratch" "${LINK_BOTH[@]}")" || fail "install.sh --link exited $?: $out"
  [ "$(installed_links "$scratch")" = "$(expected_links both)" ] || fail "the links are not the checkout's: $(installed_links "$scratch")"
  for skill in "${SKILLS[@]}"; do
    [ ! -L "$scratch/.agents/skills/$skill" ] || fail "Codex $skill is a link, so it was not rewritten"
    [ -f "$scratch/.agents/skills/$skill/SKILL.md" ] || fail "Codex $skill was not installed"
  done
  grep -qF "\$grill-to-waves" "$scratch/.agents/skills/orchestrate/SKILL.md" || fail "Codex orchestrate was not rewritten"
  [ ! -L "$scratch/.claude/settings.json" ] || fail "settings.json is a link"
  [ -z "$(replaced_backups "$scratch")" ] || fail "a link install into an empty home made a backup: $(replaced_backups "$scratch")"
  has_line "$out" '    Codex skills are copied, not linked: the installer rewrites them for Codex.' || fail "no note about the Codex copies: $out"

  links="$(installed_links "$scratch")"
  out="$(run_installer "$scratch" "${LINK_BOTH[@]}")" || fail "a second install.sh --link exited $?: $out"
  [ "$(count_lines "$out" '^    already linked ')" = "$(expected_links both | wc -l | tr -d ' ')" ] || fail "a second run did not leave every link alone: $out"
  if contains "$out" '^    (linked .* -> |unlinked )'; then fail "a second run replaced a link: $out"; fi
  [ -z "$(replaced_backups "$scratch")" ] || fail "a second run backed up a link: $(replaced_backups "$scratch")"
  [ "$links" = "$(installed_links "$scratch")" ] || fail "a second run changed the links"
  [ "$source_before" = "$(file_map "$SOURCE")" ] || fail "the install wrote into the checkout"
}

copy_then_link() {
  local scratch="$1" out
  shift
  out="$(run_installer "$scratch" --target claude --skip-mattpocock)" || fail "the copy install exited $?: $out"
  echo "a private note" > "$scratch/.claude/skills/orchestrate/PRIVATE.md"
  out="$(run_installer "$scratch" --target claude --skip-mattpocock --link "$@")" || fail "install.sh --link over a copy exited $?: $out"
  [ "$(installed_links "$scratch")" = "$(expected_links claude)" ] || fail "the copies were not replaced by links: $(installed_links "$scratch")"
  [ ! -e "$SOURCE/skills/orchestrate/PRIVATE.md" ] || fail "the replaced copy was merged into the checkout"
  printf '%s' "$out"
}

case_link_mode_backup() {
  local scratch out kept replaced
  scratch="$(new_scratch_home link-over-copy)"
  out="$(copy_then_link "$scratch")" || exit 1
  replaced="$(expected_links claude | wc -l | tr -d ' ')"
  [ "$(count_lines "$out" '^    backed up existing copy to ')" = "$replaced" ] || fail "expected $replaced backups: $out"
  kept="$(find "$scratch/.claude/backups" -mindepth 1 -maxdepth 1 -type d -name 'orchestrate-*')"
  [ -f "$kept/PRIVATE.md" ] || fail "the backup of orchestrate lost the private file: $kept"
  [ "$(find "$scratch/.claude/backups" -name "${CLAUDE_AGENTS[0]}-*" | wc -l | tr -d ' ')" = 1 ] || fail "the agent copy was not backed up"
  [ "$(find "$scratch/.claude/backups" -name 'statusline.js-*' | wc -l | tr -d ' ')" = 1 ] || fail "statusline.js was not backed up"
}

case_link_mode_no_backup() {
  local scratch out replaced
  scratch="$(new_scratch_home link-over-copy-no-backup)"
  out="$(copy_then_link "$scratch" --no-backup)" || exit 1
  replaced="$(expected_links claude | wc -l | tr -d ' ')"
  [ "$(count_lines "$out" '^    replacing .* \(no backup\)$')" = "$replaced" ] || fail "expected $replaced replacements: $out"
  [ -z "$(replaced_backups "$scratch")" ] || fail "--no-backup made a backup: $(replaced_backups "$scratch")"
}

case_link_mode_status() {
  local scratch out lines linked elsewhere
  scratch="$(new_scratch_home link-status)"
  out="$(run_installer "$scratch" "${LINK_BOTH[@]}")" || fail "install.sh --link exited $?: $out"
  linked=$((${#SKILLS[@]} + ${#CLAUDE_AGENTS[@]} + ${#CODEX_AGENTS[@]}))
  out="$(run_installer "$scratch" --status --target both)" || fail "--status after a link install exited $?: $out"
  lines="$(status_lines "$out")"
  [ "$(printf '%s\n' "$lines" | wc -l | tr -d ' ')" = "$EXPECTED_STATUS_COUNT" ] || fail "wrong number of status lines: $out"
  [ "$(count_lines "$lines" '^    linked         [^ ]+$')" = "$linked" ] || fail "expected $linked linked lines: $out"
  has_line "$out" "==> Status: ${#SKILLS[@]} identical, $linked linked, 0 differs, 0 not installed." || fail "wrong summary: $out"

  elsewhere="$scratch/.claude/agents/${CLAUDE_AGENTS[0]}"
  rm "$elsewhere"
  ln -s "$SOURCE/agents/${CLAUDE_AGENTS[1]}" "$elsewhere"
  out="$(run_installer "$scratch" --status --target both)" || fail "--status with a link elsewhere exited $?: $out"
  has_line "$out" "    differs        agents/${CLAUDE_AGENTS[0]}  (links elsewhere)" || fail "a link elsewhere was not reported as differs: $out"
  has_line "$out" "==> Status: ${#SKILLS[@]} identical, $((linked - 1)) linked, 1 differs, 0 not installed." || fail "wrong summary: $out"
}

case_link_mode_back_to_copies() {
  local scratch out source_before
  scratch="$(new_scratch_home link-back)"
  source_before="$(file_map "$SOURCE")"
  out="$(run_installer "$scratch" "${LINK_BOTH[@]}")" || fail "install.sh --link exited $?: $out"
  out="$(run_installer "$scratch" --target both --skip-mattpocock)" || fail "a copy install over links exited $?: $out"
  [ -z "$(installed_links "$scratch")" ] || fail "links were left: $(installed_links "$scratch")"
  [ "$(count_lines "$out" '^    unlinked ')" = "$(expected_links both | wc -l | tr -d ' ')" ] || fail "expected every link to be unlinked: $out"
  [ "$source_before" = "$(file_map "$SOURCE")" ] || fail "the copy install wrote into the checkout through a link"
  out="$(run_installer "$scratch" --status --target both)" || fail "--status exited $?: $out"
  has_line "$out" "==> Status: $EXPECTED_STATUS_COUNT identical, 0 linked, 0 differs, 0 not installed." || fail "the copies are not the checkout's: $out"
}

case_link_mode_needs_checkout() {
  local scratch lone="$SCRATCH_ROOT/lone" out code=0
  scratch="$(new_scratch_home link-no-checkout)"
  mkdir -p "$lone"
  cp "$SOURCE/install.sh" "$lone/"
  out="$(bash "$HERE/lib/guarded-install.sh" "$scratch" "$lone/install.sh" --target both --link 2>&1)" || code=$?
  [ "$code" = 2 ] || fail "install.sh --link without a checkout exited $code: $out"
  has_line "$out" '--link links the installed copies to a local checkout. Run it from a clone.' || fail "no refusal: $out"
  [ "$(ls -A "$scratch")" = .g2w-scratch ] || fail "install.sh --link without a checkout wrote to the home"
}

case_link_mode_parity() {
  local from_sh from_ps1 out source_before
  if ! has_pwsh; then skip "no pwsh found to run install.ps1"; fi
  from_sh="$(new_scratch_home link-parity-sh)"
  from_ps1="$(new_scratch_home link-parity-ps1)"
  source_before="$(file_map "$SOURCE")"
  out="$(run_installer "$from_sh" "${LINK_BOTH[@]}")" || fail "install.sh --link exited $?: $out"
  out="$(run_ps1_installer "$from_ps1" -Target both -SkipMattPocock -Link)" || fail "install.ps1 -Link exited $?: $out"
  [ "$(installed_links "$from_ps1")" = "$(expected_links both)" ] || fail "install.ps1 -Link made other links: $(installed_links "$from_ps1")"
  out="$(run_ps1_installer "$from_ps1" -Target both -SkipMattPocock -Link)" || fail "a second install.ps1 -Link exited $?: $out"
  [ "$(count_lines "$out" '^    already linked ')" = "$(expected_links both | wc -l | tr -d ' ')" ] || fail "a second install.ps1 -Link did not leave every link alone: $out"

  out="$(run_ps1_installer "$from_sh" -Status -Target both)" || fail "install.ps1 -Status on the install.sh links exited $?: $out"
  has_line "$out" "==> Status: ${#SKILLS[@]} identical, $((EXPECTED_STATUS_COUNT - ${#SKILLS[@]})) linked, 0 differs, 0 not installed." || fail "install.ps1 -Status disagrees: $out"
  out="$(run_installer "$from_ps1" --status --target both)" || fail "install.sh --status on the install.ps1 links exited $?: $out"
  has_line "$out" "==> Status: ${#SKILLS[@]} identical, $((EXPECTED_STATUS_COUNT - ${#SKILLS[@]})) linked, 0 differs, 0 not installed." || fail "install.sh --status disagrees: $out"

  out="$(run_ps1_installer "$from_ps1" -Target both -SkipMattPocock)" || fail "an install.ps1 copy install over links exited $?: $out"
  [ -z "$(installed_links "$from_ps1")" ] || fail "install.ps1 left links: $(installed_links "$from_ps1")"
  [ "$source_before" = "$(file_map "$SOURCE")" ] || fail "an installer wrote into the checkout"
}

playwright_expectation() {
  local chrome="$2/opt/google/chrome/chrome"
  case "$1" in
    opt) PLAYWRIGHT_ARGS=""; PLAYWRIGHT_NOTE="" ;;
    system) PLAYWRIGHT_ARGS="--executable-path $2/var/lib/flatpak/$FLATPAK_CHROME" ;;
    user) PLAYWRIGHT_ARGS="--executable-path $3/.local/share/flatpak/$FLATPAK_CHROME" ;;
    *) PLAYWRIGHT_ARGS="--browser chromium"
       PLAYWRIGHT_NOTE="no Chrome at $chrome or in a Flatpak, so playwright runs Playwright's Chromium (--browser chromium). Install it once:  npx playwright install chromium" ;;
  esac
  case "$1" in system|user) PLAYWRIGHT_NOTE="$chrome is missing, so playwright runs the Flatpak Chrome:  $PLAYWRIGHT_ARGS" ;; esac
}

playwright_scenario() {
  local root="$SCRATCH_ROOT/chrome-$1-$2" scratch out calls extra
  scratch="$(new_scratch_home "playwright-$1-$2")"
  mkdir -p "$root"
  case "$1" in opt) touch_path "$root/opt/google/chrome/chrome" ;; esac
  case "$1" in opt|system) touch_path "$root/var/lib/flatpak/$FLATPAK_CHROME" ;; esac
  case "$1" in opt|system|user) touch_path "$scratch/.local/share/flatpak/$FLATPAK_CHROME" ;; esac
  playwright_expectation "$1" "$root" "$scratch"
  export G2W_CHROME_ROOT="$root"
  rm -f "$G2W_STUB_LOG"
  if [ "$2" = sh ]; then
    out="$(run_installer "$scratch" --target both --skip-mattpocock --with-playwright-mcp)" || fail "install.sh ($1) exited $?: $out"
  else
    out="$(run_ps1_installer "$scratch" -Target both -SkipMattPocock -WithPlaywrightMcp)" || fail "install.ps1 ($1) exited $?: $out"
  fi
  calls="$(stub_calls)"
  extra="${PLAYWRIGHT_ARGS:+ $PLAYWRIGHT_ARGS}"
  has_line "$calls" "claude mcp add --scope user $PLAYWRIGHT_ADD$extra" || fail "install.$2 ($1) registered the wrong playwright for Claude Code: $calls"
  has_line "$calls" "codex mcp add $PLAYWRIGHT_ADD$extra" || fail "install.$2 ($1) registered the wrong playwright for Codex CLI: $calls"
  if [ -n "$PLAYWRIGHT_NOTE" ]; then
    has_line "$out" "    $PLAYWRIGHT_NOTE" || fail "install.$2 ($1) printed no line '$PLAYWRIGHT_NOTE': $out"
  elif contains "$out" "Playwright's browser"; then
    fail "install.$2 ($1) printed a browser note although Chrome is in place: $out"
  fi
}

case_playwright_chrome() {
  local stubs installers=(sh) installer scenario
  [ -n "$NODE" ] || skip "no node found to run the CLI stand-ins"
  [ "$(uname -s)" = Linux ] || skip "the Chrome lookup runs on Linux only"
  if has_pwsh; then installers+=(ps1); fi
  stubs="$(new_stub_dir stubs-playwright claude codex npx)"
  export PATH="$stubs:$PATH"
  for installer in "${installers[@]}"; do
    for scenario in opt system user none; do playwright_scenario "$scenario" "$installer"; done
  done
}

case_real_home() {
  diff "$SCRATCH_ROOT/real-home.before" <(real_home_fingerprint) || fail "the real home under $REAL_HOME changed during the run"
}

# --- Run ----------------------------------------------------------------------------------------
# rm does not follow links, so a link left behind by a failed test costs its target nothing.
trap 'rm -rf "$SCRATCH_ROOT"' EXIT

echo "install.sh tests - bash $BASH_VERSION"
real_home_fingerprint > "$SCRATCH_ROOT/real-home.before"

mkdir -p "$SOURCE"
cp "$REPO/install.sh" "$REPO/install.ps1" "$SOURCE/"
cp -R "$REPO/skills" "$REPO/agents" "$REPO/statusline" "$SOURCE/"
DEFAULT_STUBS="$(new_stub_dir stubs gh glab claude codex)"
export PATH="$DEFAULT_STUBS:$PATH"
export G2W_CHROME_ROOT="$SCRATCH_ROOT/chrome-present"
touch_path "$G2W_CHROME_ROOT/opt/google/chrome/chrome"

SKILLS=()
for path in "$SOURCE"/skills/*/SKILL.md; do SKILLS+=("$(basename "$(dirname "$path")")"); done
CLAUDE_AGENTS=()
for path in "$SOURCE"/agents/*.md; do CLAUDE_AGENTS+=("$(basename "$path")"); done
CODEX_AGENTS=()
for path in "$SOURCE"/agents/codex/*.toml; do CODEX_AGENTS+=("$(basename "$path")"); done
EXPECTED_STATUS_COUNT=$((2 * ${#SKILLS[@]} + ${#CLAUDE_AGENTS[@]} + ${#CODEX_AGENTS[@]}))

run_case "guard: refuses a home that is not a marked scratch directory" case_guard
run_case "end to end: --target both installs every skill and agent into the scratch home" case_end_to_end
run_case "end to end: a second install moves the replaced skill to backups" case_reinstall
run_case "end to end: --project puts skills and agents in the project, settings in the home" case_project
run_case "codex conversion: mentions, agent directory and frontmatter are rewritten, nothing else" case_codex_conversion
run_case "link destination: the link is removed and its target is left alone (with a backup)" case_link_backup
run_case "link destination: the link is removed and its target is left alone (with --no-backup)" case_link_no_backup
run_case "status: not installed, then identical, then differs, and it never writes" case_status
run_case "forge CLIs and MCP servers: reported, registered through the host CLIs, an existing name kept" case_forge_and_mcp
run_case "forge CLIs and MCP servers: what is not on PATH is reported, and a server the host has is kept" case_forge_and_mcp_missing
run_case "parity: install.sh and install.ps1 produce the same tree for --target both" case_parity
run_case "link mode: --link links every skill, agent and statusline.js to the checkout; a second run keeps them" case_link_mode_install
run_case "link mode: --link moves an existing copy to backups first" case_link_mode_backup
run_case "link mode: --link with --no-backup replaces an existing copy without a backup" case_link_mode_no_backup
run_case "link mode: --status reports a link to the checkout as linked, a link elsewhere as differs" case_link_mode_status
run_case "link mode: an install without --link replaces the links with copies and leaves the checkout alone" case_link_mode_back_to_copies
run_case "link mode: --link without a local checkout stops before any change" case_link_mode_needs_checkout
run_case "link mode parity: install.ps1 -Link makes the same links, and each status reads the other's" case_link_mode_parity
run_case "playwright: Chrome in /opt as is, else a Flatpak Chrome, else Playwright's Chromium" case_playwright_chrome
run_case "real home: ~/.claude, ~/.agents and ~/.codex are what they were before the run" case_real_home

echo "$PASSED passed, $FAILED failed, $SKIPPED skipped"
[ "$FAILED" = 0 ]
