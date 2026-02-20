#!/usr/bin/env bash
set -euo pipefail

# rtm_lists.sh — Show all RTM lists and IDs.
# Usage: ./rtm_lists.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=rtm_lib.sh
source "$DIR/rtm_lib.sh"

sig=$(rtm_api_sig \
  api_key "$RTM_API_KEY" \
  auth_token "$RTM_AUTH_TOKEN" \
  format json \
  method rtm.lists.getList)

json=$(rtm_call "https://api.rememberthemilk.com/services/rest/?method=rtm.lists.getList&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=${sig}")
rtm_fail_if_not_ok "$json"

echo "$json" | jq -r '.rsp.lists.list | (if type=="array" then . else [.] end) | .[] | "\(.name) (ID: \(.id))"'
