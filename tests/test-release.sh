#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SCRIPT_PATH=".github/scripts/prepare-release.sh"
SCRATCH_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/g2w-release-tests-XXXXXX")"
TAG="v1.2.3"
PS1_DEFAULT_REF="    [string]\$Ref = 'main',"
DOWNLOAD_URL="https://github.com/jefrykurniaone/grill-to-waves/releases/download/$TAG"
trap 'rm -rf "$SCRATCH_ROOT"' EXIT

PASSED=0
FAILED=0

run_case() {
  local log="$SCRATCH_ROOT/case.log"
  if ( set -e; "$2" ) > "$log" 2>&1; then
    PASSED=$((PASSED + 1)); echo "PASS  $1"
  else
    FAILED=$((FAILED + 1)); echo "FAIL  $1"; sed 's/^/      /' "$log"
  fi
}

fail() { printf '%s\n' "$*" >&2; exit 1; }
has_line() { grep -qxF -- "$2" "$1"; }

new_fixture() {
  local root="$SCRATCH_ROOT/$1"
  mkdir -p "$root/.github/scripts"
  cp "$REPO/$SCRIPT_PATH" "$root/$SCRIPT_PATH"
  cat > "$root/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REF="main"
echo "$REF"
EOF
  printf '%s\r\n' 'param(' "$PS1_DEFAULT_REF" ')' 'Write-Output done' > "$root/install.ps1"
  printf '%s' "$root"
}

write_changelog() {
  cat > "$1/CHANGELOG.md"
}

prepare() {
  bash "$1/$SCRIPT_PATH" "$2" "$1/out" 2>&1
}

expect_refusal() {
  local root="$1" tag="$2" message="$3" out
  if out="$(prepare "$root" "$tag")"; then fail "prepare-release accepted $tag: $out"; fi
  printf '%s\n' "$out" | grep -qF -- "$message" || fail "expected '$message', got: $out"
  [ ! -e "$root/out/notes.md" ] || fail "a refused release still wrote notes"
}

case_notes_are_the_tag_section() {
  local root
  root="$(new_fixture notes)"
  write_changelog "$root" <<'EOF'
# Changelog

## v1.2.3 — 2026-11-21

The summary line.

### Added

- A thing.

## 2026-11-20 — An older entry

- Must not appear.
EOF
  prepare "$root" "$TAG" >/dev/null || fail "prepare-release failed"
  head -n 1 "$root/out/notes.md" | grep -qxF "The summary line." || fail "notes do not start at the section body"
  has_line "$root/out/notes.md" "- A thing." || fail "notes lost the section's list"
  ! grep -qF "Must not appear." "$root/out/notes.md" || fail "notes ran into the next entry"
  has_line "$root/out/notes.md" "curl -fsSL $DOWNLOAD_URL/install.sh | bash" || fail "notes lack the pinned bash install"
  has_line "$root/out/notes.md" "irm $DOWNLOAD_URL/install.ps1 | iex" || fail "notes lack the pinned PowerShell install"
}

case_installers_default_to_the_tag() {
  local root changed
  root="$(new_fixture stamp)"
  printf '## %s — 2026-11-21\n\nNotes.\n' "$TAG" | write_changelog "$root"
  prepare "$root" "$TAG" >/dev/null || fail "prepare-release failed"
  changed="$(diff "$root/install.sh" "$root/out/install.sh" | grep -c '^[<>]')"
  [ "$changed" = 2 ] || fail "install.sh changed on more than its default ref line"
  has_line "$root/out/install.sh" "REF=\"$TAG\"" || fail "install.sh does not default to $TAG"
  [ -x "$root/out/install.sh" ] || fail "the stamped install.sh is not executable"
  bash -n "$root/out/install.sh" || fail "the stamped install.sh does not parse"
  has_line "$root/out/install.ps1" "    [string]\$Ref = '$TAG',"$'\r' || fail "install.ps1 does not default to $TAG with CRLF kept"
  [ "$(grep -c $'\r$' "$root/out/install.ps1")" = 4 ] || fail "install.ps1 lost a CRLF line ending"
}

case_refuses_a_tag_that_is_not_semver() {
  local root
  root="$(new_fixture semver)"
  printf '## 1.2.3 — 2026-11-21\n\nNotes.\n' | write_changelog "$root"
  expect_refusal "$root" "1.2.3" "the tag must look like vX.Y.Z"
}

case_refuses_a_tag_without_a_changelog_heading() {
  local root
  root="$(new_fixture missing)"
  printf '## 2026-11-21 — Dated only\n\nNotes.\n' | write_changelog "$root"
  expect_refusal "$root" "$TAG" "CHANGELOG.md has no '## $TAG — <date>' heading"
}

case_refuses_an_empty_section() {
  local root
  root="$(new_fixture empty)"
  printf '## %s — 2026-11-21\n\n\n## 2026-11-20 — Older\n\nNotes.\n' "$TAG" | write_changelog "$root"
  expect_refusal "$root" "$TAG" "the CHANGELOG.md section for $TAG is empty"
}

case_refuses_an_installer_without_its_default_ref() {
  local root out
  root="$(new_fixture no-default)"
  printf '## %s — 2026-11-21\n\nNotes.\n' "$TAG" | write_changelog "$root"
  printf 'REF="develop"\n' > "$root/install.sh"
  if out="$(prepare "$root" "$TAG")"; then fail "prepare-release stamped an installer without a main default: $out"; fi
  printf '%s\n' "$out" | grep -qF "expected one default ref line" || fail "unexpected refusal: $out"
}

case_repository_installers_carry_one_default_ref() {
  [ "$(grep -c '^REF="main"' "$REPO/install.sh")" = 1 ] || fail "install.sh must default REF to main exactly once"
  [ "$(grep -cF "$PS1_DEFAULT_REF" "$REPO/install.ps1")" = 1 ] || fail "install.ps1 must default \$Ref to main exactly once"
}

run_case "notes: the tag's CHANGELOG section, stopped at the next entry, with pinned install lines" case_notes_are_the_tag_section
run_case "stamp: each installer defaults to the tag, nothing else changes, CRLF kept" case_installers_default_to_the_tag
run_case "refusal: a tag that is not vX.Y.Z" case_refuses_a_tag_that_is_not_semver
run_case "refusal: a tag with no CHANGELOG heading" case_refuses_a_tag_without_a_changelog_heading
run_case "refusal: a tag whose CHANGELOG section is empty" case_refuses_an_empty_section
run_case "refusal: an installer whose default ref is not main" case_refuses_an_installer_without_its_default_ref
run_case "repository: install.sh and install.ps1 each carry the one default ref the stamp replaces" case_repository_installers_carry_one_default_ref

echo "$PASSED passed, $FAILED failed"
[ "$FAILED" = 0 ]
