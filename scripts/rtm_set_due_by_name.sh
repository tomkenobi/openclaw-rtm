#!/usr/bin/env bash
set -euo pipefail

# rtm_set_due_by_name.sh — Set due date for the first incomplete task matching name:<term>
#
# Usage:
#   ./rtm_set_due_by_name.sh "milk" "2026-02-20"
#   ./rtm_set_due_by_name.sh "Chorverband" "tomorrow"
#
# DUE can be an RTM-parsable string (e.g. 2026-02-20, tomorrow, next week).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=rtm_lib.sh
source "$DIR/rtm_lib.sh"

TERM="${1:-}"
DUE="${2:-}"

if [[ -z "$TERM" || -z "$DUE" ]]; then
  echo "Usage: $0 \"search term\" \"due\"" >&2
  exit 2
fi

FILTER="status:incomplete AND name:$TERM"

sig=$(rtm_api_sig \
  api_key "$RTM_API_KEY" \
  auth_token "$RTM_AUTH_TOKEN" \
  filter "$FILTER" \
  format json \
  method rtm.tasks.getList)

json=$(rtm_call "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&filter=$(printf '%s' "$FILTER" | rtm_urlenc)&auth_token=${RTM_AUTH_TOKEN}&api_sig=${sig}")
rtm_fail_if_not_ok "$json"

LIST_ID=$(echo "$json" | jq -r '.rsp.tasks.list | (if type=="array" then .[0] else . end) | .id // empty')
TASKSERIES_ID=$(echo "$json" | jq -r '.rsp.tasks.list | (if type=="array" then .[0] else . end) | .taskseries | (if type=="array" then .[0] else . end) | .id // empty')
TASK_ID=$(echo "$json" | jq -r '.rsp.tasks.list | (if type=="array" then .[0] else . end) | .taskseries | (if type=="array" then .[0] else . end) | .task | (if type=="array" then .[0] else . end) | .id // empty')
NAME=$(echo "$json" | jq -r '.rsp.tasks.list | (if type=="array" then .[0] else . end) | .taskseries | (if type=="array" then .[0] else . end) | .name // empty')

if [[ -z "$LIST_ID" || -z "$TASKSERIES_ID" || -z "$TASK_ID" ]]; then
  echo "No matching incomplete task found for: $TERM" >&2
  exit 1
fi

TIMELINE=$(rtm_timeline_create)

sig=$(rtm_api_sig \
  api_key "$RTM_API_KEY" \
  auth_token "$RTM_AUTH_TOKEN" \
  due "$DUE" \
  format json \
  list_id "$LIST_ID" \
  method rtm.tasks.setDueDate \
  task_id "$TASK_ID" \
  taskseries_id "$TASKSERIES_ID" \
  timeline "$TIMELINE")

res=$(rtm_call "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.setDueDate&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&list_id=${LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&due=$(printf '%s' "$DUE" | rtm_urlenc)&auth_token=${RTM_AUTH_TOKEN}&api_sig=${sig}")
rtm_fail_if_not_ok "$res"

echo "✅ Due set: $NAME → $DUE"
