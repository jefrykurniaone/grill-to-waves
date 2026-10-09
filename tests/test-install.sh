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
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
REAL_HOME="$HOME"
REAL_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SCRATCH_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/g2w-tests-XXXXXX")"
SOURCE="$SCRATCH_ROOT/source"
MENTION='(orchestrate|grill-to-waves|ship-it-to|daily-recap|jira-comment|setup-matt-pocock-skills|grilling|domain-modeling)'
INSTALLED_PATHS=(.claude/skills .claude/agents .claude/statusline.js .agents/skills .codex/agents)
SKIP_CODE=77

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
  bash "$HERE/lib/guarded-install.sh" "$scratch" "$SOURCE/install.sh" "$@" 2>&1
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

status_lines() { printf '%s\n' "$1" | grep -E '^    (identical|differs|not installed) {2,}[^ ]' || true; }

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

  out="$(run_installer "$scratch" --target both --skip-mattpocock)" || fail "install before --status exited $?: $out"
  installed="$(file_map "$scratch")"
  out="$(run_installer "$scratch" --status --target both)" || fail "--status after an install exited $?: $out"
  lines="$(status_lines "$out")"
  [ "$(printf '%s\n' "$lines" | wc -l | tr -d ' ')" = "$EXPECTED_STATUS_COUNT" ] || fail "wrong number of status lines: $out"
  [ -z "$(printf '%s\n' "$lines" | grep -vE '^    identical      [^ ]+$' || true)" ] || fail "a fresh install is not identical: $out"
  has_line "$out" "==> Status: $EXPECTED_STATUS_COUNT identical, 0 differs, 0 not installed." || fail "wrong summary: $out"
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
  has_line "$out" "==> Status: $((EXPECTED_STATUS_COUNT - 4)) identical, 3 differs, 1 not installed." || fail "wrong summary: $out"
  [ "$changed" = "$(file_map "$scratch")" ] || fail "--status changed a tree that differs"
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
run_case "parity: install.sh and install.ps1 produce the same tree for --target both" case_parity
run_case "real home: ~/.claude, ~/.agents and ~/.codex are what they were before the run" case_real_home

echo "$PASSED passed, $FAILED failed, $SKIPPED skipped"
[ "$FAILED" = 0 ]
