#!/usr/bin/env bash
# Wait until one of several herdr agents settles after a known state change, then print its state.
#
# Read-only. One process watches every session given as <name>:<after-seq>. Each poll reads
# `herdr agent get <name>` for each of them. A session has settled when its state_change_seq is above
# its <after-seq> and its status is idle, done, blocked or unknown. The watcher then prints
# `settled <name>` and herdr's JSON for that session, and exits 0.
#
# A pause is not a settle. When an idle or done session's last outcome line on screen is
# `orchestrate: waiting on executors`, the watcher takes that sequence number as the session's new
# baseline and keeps waiting, so the caller is not woken to do nothing.
#
# A change that happened before the watcher started is caught on the first poll, so no settle is lost
# between the caller's read and the watcher. Exits 1 with `gone <name>` and herdr's error when an
# agent is gone, 2 on a malformed argument, and 3 with `timeout` when the timeout runs out (0 waits
# indefinitely).
#
#   ./scripts/watch.sh [--interval <seconds>] [--timeout <seconds>] [--lines <n>] <name>:<after-seq> ...
set -u

usage() {
  echo "usage: watch.sh [--interval <seconds>] [--timeout <seconds>] [--lines <n>] <name>:<after-seq> ..." >&2
  exit 2
}

interval=60
timeout=3600
lines=25
names=()
afters=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --interval | --timeout | --lines)
      [ "$#" -ge 2 ] || usage
      case "$2" in '' | *[!0-9]*) usage ;; esac
      case "$1" in
        --interval) interval="$2" ;;
        --timeout) timeout="$2" ;;
        --lines) lines="$2" ;;
      esac
      shift 2
      ;;
    ?*:*)
      seq="${1##*:}"
      case "$seq" in
        '' | *[!0-9]*)
          echo "watch.sh: '$1' is not <name>:<after-seq>" >&2
          exit 2
          ;;
      esac
      names+=("${1%:*}")
      afters+=("$seq")
      shift
      ;;
    *) usage ;;
  esac
done
[ "${#names[@]}" -gt 0 ] || usage

# True when the last outcome line on the session's screen is the pause line.
paused() {
  local screen last
  screen="$(herdr agent read "$1" --source recent-unwrapped --lines "$lines" 2>/dev/null)" || return 1
  last="$(printf '%s\n' "$screen" | grep -oE 'orchestrate: (done|stopped|waiting on executors)' | tail -n 1)"
  [ "$last" = 'orchestrate: waiting on executors' ]
}

started="$(date +%s)"

while :; do
  for i in "${!names[@]}"; do
    name="${names[$i]}"
    if ! out="$(herdr agent get "$name" 2>&1)"; then
      printf 'gone %s\n%s\n' "$name" "$out"
      exit 1
    fi
    # herdr prints one compact JSON object; each field occurs once in an agent's state.
    seq="$(printf '%s' "$out" | sed -n 's/.*"state_change_seq":[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
    status="$(printf '%s' "$out" | sed -n 's/.*"agent_status":[[:space:]]*"\([a-z_]*\)".*/\1/p')"
    [ -n "$seq" ] && [ "$seq" -gt "${afters[$i]}" ] || continue
    case "$status" in
      idle | done)
        if paused "$name"; then
          afters[i]="$seq"
          continue
        fi
        ;;
      blocked | unknown) ;;
      *) continue ;;
    esac
    printf 'settled %s\n%s\n' "$name" "$out"
    exit 0
  done
  if [ "$timeout" -gt 0 ] && [ $(($(date +%s) - started)) -ge "$timeout" ]; then
    echo timeout
    exit 3
  fi
  sleep "$interval"
done
