#!/usr/bin/env bash
set -euo pipefail

# rtm_list.sh — List tasks using an RTM filter.
#
# Usage:
#   ./rtm_list.sh 'status:incomplete'
#   ./rtm_list.sh 'due:today'
#   ./rtm_list.sh 'dueBefore:today'
#   ./rtm_list.sh 'list:Sharky'
#
# Output: one task per line (list name + task name)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=rtm_lib.sh
source "$DIR/rtm_lib.sh"

FILTER="${1:-status:incomplete}"

sig=$(rtm_api_sig \
  api_key "$RTM_API_KEY" \
  auth_token "$RTM_AUTH_TOKEN" \
  filter "$FILTER" \
  format json \
  method rtm.tasks.getList)

json=$(rtm_call "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&filter=$(printf '%s' "$FILTER" | rtm_urlenc)&auth_token=${RTM_AUTH_TOKEN}&api_sig=${sig}")
rtm_fail_if_not_ok "$json"

# list may be object or array; taskseries may be object or array
echo "$json" | jq -r '
  .rsp.tasks.list
  | (if type=="array" then . else [.] end)
  | .[]
  | .name as $listname
  | .taskseries
  | (if type=="array" then . else [.] end)
  | .[]
  | "[" + $listname + "] " + .name
' 2>/dev/null
