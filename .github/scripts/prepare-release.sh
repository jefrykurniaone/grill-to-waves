#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="jefrykurniaone/grill-to-waves"
SEMVER_TAG='^v[0-9]+\.[0-9]+\.[0-9]+$'
HEADING_SEPARATOR=" — "
USAGE="usage: prepare-release.sh vX.Y.Z OUT_DIR"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHANGELOG="$ROOT/CHANGELOG.md"

fail() { printf 'prepare-release: %s\n' "$1" >&2; exit 1; }

changelog_section() {
  awk -v heading="## $1$HEADING_SEPARATOR" '
    index($0, heading) == 1 { found = 1; next }
    found && /^## / { exit }
    found { lines[++n] = $0; if ($0 != "") { last = n; if (!first) first = n } }
    END { if (first) for (i = first; i <= last; i++) print lines[i] }
  ' "$CHANGELOG"
}

has_changelog_heading() {
  awk -v heading="## $1$HEADING_SEPARATOR" 'index($0, heading) == 1 { found = 1 } END { exit !found }' "$CHANGELOG"
}

write_notes() {
  local tag="$1" section="$2" download="https://github.com/$REPO_SLUG/releases/download/$1"
  cat <<EOF
$section

---

### Install this release

\`\`\`bash
curl -fsSL $download/install.sh | bash
\`\`\`

\`\`\`powershell
irm $download/install.ps1 | iex
\`\`\`

Every change up to this release: [CHANGELOG.md](https://github.com/$REPO_SLUG/blob/$tag/CHANGELOG.md)
EOF
}

stamp_default_ref() {
  local source="$1" destination="$2" pattern="$3" replacement="$4" count
  count="$(grep -c -- "$pattern" "$source" || true)"
  [ "$count" = 1 ] || fail "expected one default ref line matching '$pattern' in $source, found $count"
  sed "s#$pattern#$replacement#" "$source" > "$destination"
}

main() {
  [ $# -eq 2 ] || fail "$USAGE"
  local tag="$1" out="$2" section
  [[ "$tag" =~ $SEMVER_TAG ]] || fail "the tag must look like vX.Y.Z, got '$tag'"
  has_changelog_heading "$tag" || fail "CHANGELOG.md has no '## $tag$HEADING_SEPARATOR<date>' heading"
  section="$(changelog_section "$tag")"
  [ -n "$section" ] || fail "the CHANGELOG.md section for $tag is empty"

  mkdir -p "$out"
  write_notes "$tag" "$section" > "$out/notes.md"
  stamp_default_ref "$ROOT/install.sh" "$out/install.sh" '^REF="main"' "REF=\"$tag\""
  stamp_default_ref "$ROOT/install.ps1" "$out/install.ps1" "^    \\[string\\]\\\$Ref = 'main'," "    [string]\$Ref = '$tag',"
  chmod +x "$out/install.sh"
  printf 'prepare-release: %s notes and installers written to %s\n' "$tag" "$out"
}

main "$@"
