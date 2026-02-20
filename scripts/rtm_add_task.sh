#!/usr/bin/env bash
set -euo pipefail

# rtm_add_task.sh — Add a task (optionally with tags) to Remember The Milk via the REST API.
#
# Requirements:
#   - env: RTM_API_KEY, RTM_SHARED_SECRET, RTM_AUTH_TOKEN
#   - bins: curl, jq, md5sum
#
# Usage:
#   ./rtm_add_task.sh "Buy milk" "shopping,urgent"
#   ./rtm_add_task.sh "Pay invoice"           # no tags

TASK_NAME="${1:-}"
TAGS="${2:-}"

if [[ -z "$TASK_NAME" ]]; then
  echo "Usage: $0 \"Task name\" [comma,separated,tags]" >&2
  exit 2
fi

: "${RTM_API_KEY:?RTM_API_KEY is required}"
: "${RTM_SHARED_SECRET:?RTM_SHARED_SECRET is required}"
: "${RTM_AUTH_TOKEN:?RTM_AUTH_TOKEN is required}"

api_call() {
  local url="$1"
  curl -fsSL "$url"
}

md5() {
  md5sum | awk '{print $1}'
}

urlenc() {
  # url-encode from stdin
  jq -sRr @uri
}

# 1) Create timeline (required for write operations)
SIG_BASE="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.timelines.create"
API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_BASE}" | md5)
TIMELINE_JSON=$(api_call "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

if [[ $(echo "$TIMELINE_JSON" | jq -r '.rsp.stat') != "ok" ]]; then
  echo "❌ Failed to create timeline: $(echo "$TIMELINE_JSON" | jq -r '.rsp.err.msg // "Unknown error"')" >&2
  exit 1
fi

TIMELINE=$(echo "$TIMELINE_JSON" | jq -r '.rsp.timeline')

# 2) Add task
ENC_NAME=$(printf '%s' "$TASK_NAME" | urlenc)
SIG_BASE="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.tasks.addname${TASK_NAME}timeline${TIMELINE}"
API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_BASE}" | md5)

ADD_JSON=$(api_call "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.add&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&name=${ENC_NAME}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

if [[ $(echo "$ADD_JSON" | jq -r '.rsp.stat') != "ok" ]]; then
  echo "❌ Failed to add task: $(echo "$ADD_JSON" | jq -r '.rsp.err.msg // "Unknown error"')" >&2
  exit 1
fi

LIST_ID=$(echo "$ADD_JSON" | jq -r '.rsp.list.id')
TASKSERIES_ID=$(echo "$ADD_JSON" | jq -r '.rsp.list.taskseries | if type=="array" then .[0] else . end | .id')
TASK_ID=$(echo "$ADD_JSON" | jq -r '.rsp.list.taskseries | if type=="array" then .[0] else . end | .task | if type=="array" then .[0] else . end | .id')
NAME=$(echo "$ADD_JSON" | jq -r '.rsp.list.taskseries | if type=="array" then .[0] else . end | .name')

echo "✅ Added: $NAME"

# 3) Add tags (optional)
if [[ -n "$TAGS" ]]; then
  ENC_TAGS=$(printf '%s' "$TAGS" | urlenc)
  SIG_BASE="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonlist_id${LIST_ID}methodrtm.tasks.addTagstags${TAGS}task_id${TASK_ID}taskseries_id${TASKSERIES_ID}timeline${TIMELINE}"
  API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_BASE}" | md5)

  TAG_JSON=$(api_call "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.addTags&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&list_id=${LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&tags=${ENC_TAGS}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

  if [[ $(echo "$TAG_JSON" | jq -r '.rsp.stat') == "ok" ]]; then
    echo "🏷️ Tags: $TAGS"
  else
    echo "⚠️ Failed to add tags: $(echo "$TAG_JSON" | jq -r '.rsp.err.msg // "Unknown error"')" >&2
  fi
fi
