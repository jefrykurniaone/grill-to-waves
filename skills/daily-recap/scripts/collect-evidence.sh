#!/usr/bin/env bash
# Collects the raw evidence for a daily work recap: the day's commits, and what each of that day's
# coding-agent sessions was asked to do and reported back.
#
# Read-only. It writes nothing and changes no repository state. Requires git and jq.
#
#   ./collect-evidence.sh                                  # today, repositories under the current directory
#   ./collect-evidence.sh --date yesterday
#   ./collect-evidence.sh --date 2026-09-22 --root ~/work --root ~/src
set -uo pipefail

DATE_ARG=today
ROOTS=()
PROMPT_CHARS=400
SUMMARY_CHARS=1500

while [ $# -gt 0 ]; do
  case "$1" in
    --date)   DATE_ARG="$2"; shift 2 ;;
    --root)   ROOTS+=("$2"); shift 2 ;;
    --prompt-chars)  PROMPT_CHARS="$2"; shift 2 ;;
    --summary-chars) SUMMARY_CHARS="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ ${#ROOTS[@]} -eq 0 ] && ROOTS=("$PWD")

command -v jq >/dev/null 2>&1 || { echo "jq is required: https://jqlang.github.io/jq/" >&2; exit 1; }

if date -d today +%s >/dev/null 2>&1; then GNU_DATE=1; else GNU_DATE=0; fi

day_of() {  # today | yesterday | YYYY-MM-DD  ->  YYYY-MM-DD
  case "$1" in
    today)     date +%Y-%m-%d ;;
    yesterday) if [ $GNU_DATE = 1 ]; then date -d yesterday +%Y-%m-%d; else date -v-1d +%Y-%m-%d; fi ;;
    *)         echo "$1" ;;
  esac
}
utc_of() {  # local "YYYY-MM-DD HH:MM" -> UTC ISO, for comparing against transcript timestamps
  if [ $GNU_DATE = 1 ]; then date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ
  else date -j -f "%Y-%m-%d %H:%M" "$1" -u +%Y-%m-%dT%H:%M:%SZ; fi
}
hm_of() {   # UTC ISO -> local HH:MM
  local s="${1%%.*}"; s="${s%Z}"
  if [ $GNU_DATE = 1 ]; then date -d "${s}Z" +%H:%M
  else date -r "$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$s" +%s)" +%H:%M; fi
}

DAY="$(day_of "$DATE_ARG")"
if [ $GNU_DATE = 1 ]; then NEXT="$(date -d "$DAY +1 day" +%Y-%m-%d)"; else NEXT="$(date -j -v+1d -f %Y-%m-%d "$DAY" +%Y-%m-%d)"; fi
FROM="$(utc_of "$DAY 00:00")"
TO="$(utc_of "$NEXT 00:00")"

echo "# Evidence for $DAY"
echo

# --- Commits ----------------------------------------------------------------
echo "## Commits"
echo
found=0
for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue
  for repo in "$root" "$root"/*; do
    [ -d "$repo/.git" ] || continue
    log="$(git -C "$repo" log --all --since="$DAY 00:00" --until="$NEXT 00:00" --format='%h|%ad|%an|%s' --date=format:'%H:%M' 2>/dev/null)"
    [ -n "$log" ] || continue
    found=1
    me="$(git -C "$repo" config user.name 2>/dev/null)"
    echo "### $(basename "$repo")  (on $(git -C "$repo" branch --show-current 2>/dev/null), this machine commits as '$me')"
    while IFS='|' read -r _hash time author subject; do
      [ -n "$time" ] || continue
      mark=' '; [ "$author" = "$me" ] && mark='*'
      printf '%s %s %-14s %s\n' "$mark" "$time" "$author" "$subject"
    done <<< "$log"
    dirty="$(git -C "$repo" status --short 2>/dev/null | wc -l | tr -d ' ')"
    [ "$dirty" != 0 ] && echo "  (uncommitted changes present: $dirty paths)"
    echo
  done
done
[ $found = 0 ] && { echo "No commits in the window under: ${ROOTS[*]}"; echo; }
echo "Lines marked * are this machine's own commits. Everything else is a teammate or upstream."
echo

# --- Sessions ---------------------------------------------------------------
echo "## Sessions"
echo

SKIP='^(<task-notification|<system-reminder|<local-command|<user_instructions|<environment_context|<app-context|<recommended_plugins|\[Request interrupted)'
# Housekeeping commands carry no work: "/clear clear", "/model model", "/compact", ...
NOISE='^/?(clear|model|compact|cost|status|resume|exit|help|config|context|login|logout|init)( \1)? *$'

print_prompts() {  # reads "utc-timestamp<TAB>text" lines
  while IFS=$'\t' read -r ts text; do
    [ -n "$text" ] || continue
    text="${text#/}"
    [[ "$text" =~ $SKIP ]] && continue
    [[ "$text" =~ $NOISE ]] && continue
    [ ${#text} -gt "$PROMPT_CHARS" ] && text="${text:0:$PROMPT_CHARS}..."
    echo "[$(hm_of "$ts")] $text"
  done
}

# Claude Code: ~/.claude/projects/<project>/<session>.jsonl
claude_root="$HOME/.claude/projects"
if [ -d "$claude_root" ]; then
  while IFS= read -r f; do
    case "$f" in */subagents/*) continue ;; esac
    prompts="$(jq -r --arg from "$FROM" --arg to "$TO" '
      select(.type == "user" and (.isMeta | not) and (.isSidechain | not))
      | select(.timestamp != null and .timestamp >= $from and .timestamp < $to)
      | .timestamp as $ts
      | (.message.content) as $c
      | (if ($c | type) == "string" then $c else ([$c[]? | select(.type == "text") | .text] | join(" ")) end)
      | select(. != null and . != "")
      | gsub("</?command-(name|message|args)>"; " ") | gsub("\\s+"; " ")
      | $ts + "\t" + (. | ltrimstr(" ") | rtrimstr(" "))' "$f" 2>/dev/null | print_prompts)"
    closing="$(jq -rs --arg from "$FROM" --arg to "$TO" '
      [ .[] | select(.type == "assistant" and .timestamp >= $from and .timestamp < $to)
            | ([.message.content[]? | select(.type == "text") | .text] | join("\n")) ]
      | map(select(length > 0)) | last // empty' "$f" 2>/dev/null | head -c "$SUMMARY_CHARS")"
    [ -z "$prompts" ] && [ -z "$closing" ] && continue
    project="$(basename "$(dirname "$f")")"
    echo "### Claude Code - $project - $(basename "$f" .jsonl | cut -c1-8) (last active $(date -r "$f" +%H:%M))"
    echo "**Asked for:**"
    echo "$prompts"
    if [ -n "$closing" ]; then echo; echo "**Closing report:**"; echo "$closing"; fi
    echo
  done < <(find "$claude_root" -name '*.jsonl' -type f -newermt "$DAY 00:00" ! -newermt "$NEXT 00:00" 2>/dev/null)
fi

# Codex CLI: ~/.codex/sessions/<yyyy>/<MM>/<dd>/rollout-*.jsonl
codex_root="$HOME/.codex/sessions"
if [ -d "$codex_root" ]; then
  while IFS= read -r f; do
    prompts="$(jq -r --arg from "$FROM" --arg to "$TO" '
      select(.type == "response_item" and .payload.type == "message" and .payload.role == "user")
      | select(.timestamp != null and .timestamp >= $from and .timestamp < $to)
      | .timestamp as $ts
      | ([.payload.content[]? | .text // empty] | join(" "))
      | select(. != "") | gsub("\\s+"; " ")
      | $ts + "\t" + .' "$f" 2>/dev/null | print_prompts)"
    closing="$(jq -rs --arg from "$FROM" --arg to "$TO" '
      [ .[] | select(.type == "response_item" and .payload.type == "message" and .payload.role == "assistant")
            | select(.timestamp >= $from and .timestamp < $to)
            | ([.payload.content[]? | .text // empty] | join("\n")) ]
      | map(select(length > 0)) | last // empty' "$f" 2>/dev/null | head -c "$SUMMARY_CHARS")"
    [ -z "$prompts" ] && [ -z "$closing" ] && continue
    cwd="$(jq -r 'select(.type == "session_meta") | .payload.cwd // empty' "$f" 2>/dev/null | head -1)"
    echo "### Codex - $(basename "${cwd:-session}") - $(basename "$f" .jsonl) (last active $(date -r "$f" +%H:%M))"
    echo "**Asked for:**"
    echo "$prompts"
    if [ -n "$closing" ]; then echo; echo "**Closing report:**"; echo "$closing"; fi
    echo
  done < <(find "$codex_root" -name '*.jsonl' -type f -newermt "$DAY 00:00" ! -newermt "$NEXT 00:00" 2>/dev/null)
fi
