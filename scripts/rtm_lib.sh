#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for RTM API scripts.
# Requirements: curl, jq, md5sum

: "${RTM_API_KEY:?RTM_API_KEY is required}"
: "${RTM_SHARED_SECRET:?RTM_SHARED_SECRET is required}"
: "${RTM_AUTH_TOKEN:?RTM_AUTH_TOKEN is required}"

rtm_urlenc() {
  jq -sRr @uri
}

rtm_md5() {
  md5sum | awk '{print $1}'
}

# Build RTM api_sig according to RTM rules:
# api_sig = md5(shared_secret + concatenated key/value pairs sorted by key)
# Params must include: api_key, method, format=json, and auth_token for signed calls.
rtm_api_sig() {
  # usage: rtm_api_sig key value [key value ...]
  local -a kv=()
  while [[ $# -gt 0 ]]; do
    kv+=("$1=$2")
    shift 2
  done

  printf '%s\n' "${kv[@]}" \
    | LC_ALL=C sort \
    | awk -F= '{printf "%s%s", $1, $2}' \
    | { printf '%s' "${RTM_SHARED_SECRET}"; cat; } \
    | rtm_md5
}

rtm_call() {
  local url="$1"
  curl -fsSL "$url"
}

rtm_fail_if_not_ok() {
  local json="$1"
  local stat
  stat=$(echo "$json" | jq -r '.rsp.stat // "fail"')
  if [[ "$stat" != "ok" ]]; then
    local msg
    msg=$(echo "$json" | jq -r '.rsp.err.msg // "Unknown error"')
    echo "❌ RTM API error: $msg" >&2
    return 1
  fi
}

rtm_timeline_create() {
  local sig
  sig=$(rtm_api_sig \
    api_key "$RTM_API_KEY" \
    auth_token "$RTM_AUTH_TOKEN" \
    format json \
    method rtm.timelines.create)

  local json
  json=$(rtm_call "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=${sig}")
  rtm_fail_if_not_ok "$json"
  echo "$json" | jq -r '.rsp.timeline'
}
