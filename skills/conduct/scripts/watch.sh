#!/usr/bin/env bash
# Wait until a herdr agent settles after a known state change, then print its state.
#
# Read-only. Polls `herdr agent get <agent>` until its state_change_seq is above <after-seq> and its
# status is idle, done, blocked or unknown, then prints herdr's JSON and exits 0. A change that
# happened before the watcher started is caught on the first poll, so no settle is lost between the
# caller's read and the watcher. Exits 1 with herdr's error when the agent is gone, and 3 when
# <timeout-seconds> (0, the default, waits indefinitely) runs out.
#
#   ./scripts/watch.sh <agent> <after-seq> [interval-seconds] [timeout-seconds]
set -u

if [ "$#" -lt 2 ]; then
  echo "usage: watch.sh <agent> <after-seq> [interval-seconds] [timeout-seconds]" >&2
  exit 2
fi
agent="$1"
after="$2"
interval="${3:-20}"
timeout="${4:-0}"
started="$(date +%s)"

while :; do
  if ! out="$(herdr agent get "$agent" 2>&1)"; then
    printf '%s\n' "$out"
    exit 1
  fi
  # herdr prints one compact JSON object; each field occurs once in an agent's state.
  seq="$(printf '%s' "$out" | sed -n 's/.*"state_change_seq":[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
  status="$(printf '%s' "$out" | sed -n 's/.*"agent_status":[[:space:]]*"\([a-z_]*\)".*/\1/p')"
  if [ -n "$seq" ] && [ "$seq" -gt "$after" ]; then
    case "$status" in
      idle | done | blocked | unknown)
        printf '%s\n' "$out"
        exit 0
        ;;
    esac
  fi
  if [ "$timeout" -gt 0 ] && [ $(($(date +%s) - started)) -ge "$timeout" ]; then
    printf '%s\n' "$out"
    exit 3
  fi
  sleep "$interval"
done
