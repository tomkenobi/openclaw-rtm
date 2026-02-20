---
name: rtm
description: "Remember The Milk integration - Manage tasks, lists, and reminders via the RTM API. Use when: adding tasks, checking todo lists, completing items, setting due dates, or managing RTM tasks."
homepage: https://www.rememberthemilk.com/services/api/
metadata: {"clawdbot":{"emoji":"🥛","requires":{"bins":["jq","curl"],"env":["RTM_API_KEY","RTM_SHARED_SECRET","RTM_AUTH_TOKEN","RTM_USERNAME"]}}}
---

# Remember The Milk (RTM) Skill

Manage your Remember The Milk tasks directly from Clawdbot. Perfect for quick task additions, checking your todo list, and marking items complete.

> ⚠️ **WICHTIG:** Die RTM API parst KEINE Smart Add Syntax (wie `#tag`, `^date`, `!priority`) in Task-Namen. Du musst separate API-Aufrufe für Tags, Due-Dates und Prioritäten verwenden!

## Setup

1. Get API credentials from https://www.rememberthemilk.com/services/api/
2. Authenticate and obtain auth token
3. Set environment variables in `~/.openclaw/.env`:
   ```bash
   RTM_API_KEY=your_api_key
   RTM_SHARED_SECRET=your_shared_secret
   RTM_USERNAME=your_rtm_username
   RTM_AUTH_TOKEN=your_auth_token
   ```

## RTM API Helper Functions

### Sign API Request
```bash
# Hilfsfunktion für RTM API Signatur-Generierung
# Alle Parameter werden alphabetisch sortiert und korrekt signiert
rtm_sign() {
  local params=""
  local has_auth_token=""
  
  # Sammle alle Parameter (key=value Paare)
  while [[ $# -gt 0 ]]; do
    local key="$1"
    local value="$2"
    shift 2
    
    # Speichere ob auth_token vorhanden ist
    if [[ "$key" == "auth_token" ]]; then
      has_auth_token="$value"
    fi
    
    # URL-encode für Signatur (nur fürs zusammenbauen der Signatur-String)
    local encoded_value=$(printf '%s' "$value" | jq -sRr @uri | tr -d '\n')
    params="${params}${key}${value}"
  done
  
  # Generiere MD5 Signatur
  echo -n "${RTM_SHARED_SECRET}${params}" | md5sum | cut -d' ' -f1
}

# Hilfsfunktion für URL-Encoding
rtm_url_encode() {
  printf '%s' "$1" | jq -sRr @uri | tr -d '\n'
}

# Hilfsfunktion für API Fehlerprüfung
rtm_check_error() {
  local response="$1"
  local stat=$(echo "$response" | jq -r '.rsp.stat // "fail"' 2>/dev/null)
  
  if [[ "$stat" != "ok" ]]; then
    local err_code=$(echo "$response" | jq -r '.rsp.err.code // "unknown"' 2>/dev/null)
    local err_msg=$(echo "$response" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)
    echo "❌ RTM API Error (Code: $err_code): $err_msg" >&2
    return 1
  fi
  return 0
}
```

### Build API URL
```bash
rtm_api_url() {
  local method="$1"
  shift
  
  # Arrays für Parameter
  local sig_params=()
  local url_params=()
  
  # Verarbeite alle Parameter als key-value Paare
  while [[ $# -gt 0 ]]; do
    local key="$1"
    local value="$2"
    shift 2
    
    sig_params+=("$key" "$value")
    local encoded_value=$(rtm_url_encode "$value")
    url_params+=("${key}=${encoded_value}")
  done
  
  # Füge auth_token hinzu wenn vorhanden
  if [[ -n "$RTM_AUTH_TOKEN" ]]; then
    sig_params+=("auth_token" "$RTM_AUTH_TOKEN")
    url_params+=("auth_token=$(rtm_url_encode "$RTM_AUTH_TOKEN")")
  fi
  
  # Sortiere Parameter alphabetisch für Signatur
  local sorted_sig=""
  local keys=()
  local values=()
  local i=0
  while [[ $i -lt ${#sig_params[@]} ]]; do
    keys+=("${sig_params[$i]}")
    values+=("${sig_params[$((i+1))]}")
    i=$((i+2))
  done
  
  # Sortiere nach Keys
  local sorted_indices=($(printf '%s\n' "${!keys[@]}" | sort -k1 < <(printf '%s\n' "${keys[@]}") -n))
  
  # Baue sortierten Signatur-String
  local sig_string=""
  for idx in "${!keys[@]}"; do
    sig_string="${sig_string}${keys[$idx]}${values[$idx]}"
  done
  
  # Generiere Signatur
  local api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}formatjsonmethod${method}${sig_string}" | md5sum | cut -d' ' -f1)
  
  # Baue URL
  local url="https://api.rememberthemilk.com/services/rest/?method=${method}&api_key=${RTM_API_KEY}&format=json"
  for param in "${url_params[@]}"; do
    url="${url}&${param}"
  done
  url="${url}&api_sig=${api_sig}"
  
  echo "$url"
}

# Einfachere Alternative: Manuelle URL-Konstruktion mit rtm_sign
rtm_build_url() {
  local method="$1"
  local sig_string="$2"
  local query_string="$3"
  
  local api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}formatjsonmethod${method}${sig_string}auth_token${RTM_AUTH_TOKEN}" | md5sum | cut -d' ' -f1)
  
  echo "https://api.rememberthemilk.com/services/rest/?method=${method}&api_key=${RTM_API_KEY}&format=json&${query_string}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${api_sig}"
}
```

## Usage

### List all tasks (default list)
```bash
# Get tasks from Inbox
TIMELINE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.timelines.create" | md5sum | cut -d' ' -f1)" | jq -r '.rsp.timeline // empty' 2>/dev/null)

if [[ -z "$TIMELINE" ]]; then
  echo "❌ Failed to create timeline"
  exit 1
fi

# Get all lists first
LISTS_JSON=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.lists.getList&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.lists.getList" | md5sum | cut -d' ' -f1)")

# Prüfe auf Fehler
if ! echo "$LISTS_JSON" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "$LISTS_JSON" | jq -r '.rsp.err.msg // "Unknown error"' >&2
  exit 1
fi

INBOX_ID=$(echo "$LISTS_JSON" | jq -r '.rsp.lists.list[] | select(.name == "Inbox" or .name == "Eingang") | .id' | head -1)

# Get tasks from Inbox
RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&list_id=${INBOX_ID}&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonlist_id${INBOX_ID}methodrtm.tasks.getList" | md5sum | cut -d' ' -f1)")

# Fehlerbehandlung
if ! echo "$RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' >&2
  exit 1
fi

# jq-Pfad für Arrays: Handle sowohl einzelne Objekte als auch Arrays
echo "$RESPONSE" | jq -r '.rsp.tasks.list[]?.taskseries[]? | "\(.name)"' 2>/dev/null
```

### Quick Task List (Simplified)
```bash
# List all tasks (all lists) - simplest version
RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&filter=status:incomplete&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}filterstatus:incompleteformatjsonmethodrtm.tasks.getList" | md5sum | cut -d' ' -f1)")

# Fehlerprüfung
if ! echo "$RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "❌ Error: $(echo "$RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
  exit 1
fi

# Korrigierter jq-Pfad für Arrays mit Fehlerunterdrückung
echo "$RESPONSE" | jq -r '.rsp.tasks.list | if type == "array" then .[] else [.] end | .taskseries | if type == "array" then .[] else [.] end | .name' 2>/dev/null | head -20
```

### Add a new task (with tags)
```bash
# Create timeline first
TIMELINE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.timelines.create" | md5sum | cut -d' ' -f1)")

if ! echo "$TIMELINE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "❌ Failed to create timeline: $(echo "$TIMELINE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
  exit 1
fi

TIMELINE=$(echo "$TIMELINE" | jq -r '.rsp.timeline')

# Add task (ohne Smart Add Syntax!)
TASK_NAME="Buy milk"
ENCODED_NAME=$(printf '%s' "$TASK_NAME" | jq -sRr @uri | tr -d '\n')

# Signatur mit auth_token (immer in Signatur aufnehmen!)
SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.tasks.addname${TASK_NAME}timeline${TIMELINE}"
API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.add&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&name=${ENCODED_NAME}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

# Fehlerbehandlung
if ! echo "$RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "❌ Error adding task: $(echo "$RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
  exit 1
fi

# Extract IDs mit korrektem jq-Pfad für Arrays
LIST_ID=$(echo "$RESPONSE" | jq -r '.rsp.list.id // empty' 2>/dev/null)
TASKSERIES_ID=$(echo "$RESPONSE" | jq -r '.rsp.list.taskseries | if type == "array" then .[0] else . end | .id' 2>/dev/null)
TASK_ID=$(echo "$RESPONSE" | jq -r '.rsp.list.taskseries | if type == "array" then .[0] else . end | .task | if type == "array" then .[0] else . end | .id' 2>/dev/null)

echo "Task added: $(echo "$RESPONSE" | jq -r '.rsp.list.taskseries | if type == "array" then .[0] else . end | .name' 2>/dev/null)"

# Add tags separately (RTM API doesn't parse #tags in task name)
TAGS="shopping,urgent"
SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonlist_id${LIST_ID}methodrtm.tasks.addTagstags${TAGS}task_id${TASK_ID}taskseries_id${TASKSERIES_ID}timeline${TIMELINE}"
API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

TAG_RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.addTags&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&list_id=${LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&tags=${TAGS}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

if echo "$TAG_RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "Tags added: $TAGS"
else
  echo "⚠️ Failed to add tags: $(echo "$TAG_RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
fi
```

### Complete a task
```bash
# First find the task ID (requires list_id, taskseries_id, task_id)
SEARCH_TERM="milk"
SEARCH_RESULT=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&filter=name:${SEARCH_TERM}&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}filtername:${SEARCH_TERM}formatjsonmethodrtm.tasks.getList" | md5sum | cut -d' ' -f1)")

# Fehlerprüfung
if ! echo "$SEARCH_RESULT" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "❌ Search failed: $(echo "$SEARCH_RESULT" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
  exit 1
fi

# Extract IDs mit robustem jq-Pfad
LIST_ID=$(echo "$SEARCH_RESULT" | jq -r '.rsp.tasks.list | if type == "array" then .[0] else . end | .id' 2>/dev/null)
TASKSERIES_ID=$(echo "$SEARCH_RESULT" | jq -r '.rsp.tasks.list | if type == "array" then .[0] else . end | .taskseries | if type == "array" then .[0] else . end | .id' 2>/dev/null)
TASK_ID=$(echo "$SEARCH_RESULT" | jq -r '.rsp.tasks.list | if type == "array" then .[0] else . end | .taskseries | if type == "array" then .[0] else . end | .task | if type == "array" then .[0] else . end | .id' 2>/dev/null)

# Complete it
TIMELINE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.timelines.create" | md5sum | cut -d' ' -f1)" | jq -r '.rsp.timeline' 2>/dev/null)

SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonlist_id${LIST_ID}methodrtm.tasks.completetask_id${TASK_ID}taskseries_id${TASKSERIES_ID}timeline${TIMELINE}"
API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

COMPLETION_RESULT=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.complete&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&list_id=${LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

if echo "$COMPLETION_RESULT" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "✅ Task completed successfully"
else
  echo "❌ Failed to complete task: $(echo "$COMPLETION_RESULT" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
fi
```

### Set due date
```bash
# Set due date for a task
DUE_DATE="2026-02-20"
TIMELINE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.timelines.create" | md5sum | cut -d' ' -f1)" | jq -r '.rsp.timeline' 2>/dev/null)

SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}due${DUE_DATE}formatjsonlist_id${LIST_ID}methodrtm.tasks.setDueDatetask_id${TASK_ID}taskseries_id${TASKSERIES_ID}timeline${TIMELINE}"
API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

RESULT=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.setDueDate&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&list_id=${LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&due=${DUE_DATE}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

if echo "$RESULT" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "✅ Due date set to $DUE_DATE"
else
  echo "❌ Error: $(echo "$RESULT" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
fi
```

## Quick Commands

### Show today's tasks
```bash
RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&filter=due:today&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}filterdue:todayformatjsonmethodrtm.tasks.getList" | md5sum | cut -d' ' -f1)")

if echo "$RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -r '.rsp.tasks.list | if type == "array" then .[] else [.] end | .taskseries | if type == "array" then .[] else [.] end | .name' 2>/dev/null
else
  echo "❌ Error: $(echo "$RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
fi
```

### Show overdue tasks
```bash
RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&filter=dueBefore:today&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}filterdueBefore:todayformatjsonmethodrtm.tasks.getList" | md5sum | cut -d' ' -f1)")

if echo "$RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -r '.rsp.tasks.list | if type == "array" then .[] else [.] end | .taskseries | if type == "array" then .[] else [.] end | .name' 2>/dev/null
else
  echo "❌ Error: $(echo "$RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
fi
```

### Show tasks by tag
```bash
RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&filter=tag:shopping&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}filtertag:shoppingformatjsonmethodrtm.tasks.getList" | md5sum | cut -d' ' -f1)")

if echo "$RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -r '.rsp.tasks.list | if type == "array" then .[] else [.] end | .taskseries | if type == "array" then .[] else [.] end | .name' 2>/dev/null
else
  echo "❌ Error: $(echo "$RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
fi
```

## Notes

- **API Rate Limit**: 1 call per second recommended
- **Authentication**: Token doesn't expire unless revoked
- **Smart Add**: Die RTM API parst KEINE Smart Add Syntax (wie `#tag` oder `^date`) in Task-Namen. Du musst separate API-Aufrufe für:
  - Tags: `rtm.tasks.addTags` nach Task-Erstellung
  - Due dates: `rtm.tasks.setDueDate`
  - Priorities: `rtm.tasks.setPriority`
- **Komplexität**: RTM benutzt 3 IDs pro Task: list_id, taskseries_id, task_id
- **Signatur**: auth_token MUSS immer in die Signatur aufgenommen werden wenn vorhanden

## Working with Lists

### Create a new list
```bash
TIMELINE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.timelines.create" | md5sum | cut -d' ' -f1)" | jq -r '.rsp.timeline' 2>/dev/null)

LIST_NAME="Sharky"
SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.lists.addname${LIST_NAME}timeline${TIMELINE}"
API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.lists.add&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&name=${LIST_NAME}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

if echo "$RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -r '.rsp.list | "List created: \(.name) (ID: \(.id))"' 2>/dev/null
else
  echo "❌ Error: $(echo "$RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
fi
```

### Move task to another list
```bash
TIMELINE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.timelines.create" | md5sum | cut -d' ' -f1)" | jq -r '.rsp.timeline' 2>/dev/null)

# Source and target list IDs
FROM_LIST_ID="17527533"  # Inbox
TO_LIST_ID="51478692"    # Sharky

# Task IDs
TASKSERIES_ID="601067674"
TASK_ID="1186296255"

SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonfrom_list_id${FROM_LIST_ID}methodrtm.tasks.moveTotask_id${TASK_ID}taskseries_id${TASKSERIES_ID}timeline${TIMELINE}to_list_id${TO_LIST_ID}"
API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.moveTo&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&from_list_id=${FROM_LIST_ID}&to_list_id=${TO_LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

if echo "$RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "✅ Task moved successfully"
else
  echo "❌ Error: $(echo "$RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
fi
```

### Get all lists
```bash
RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.lists.getList&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.lists.getList" | md5sum | cut -d' ' -f1)")

if echo "$RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -r '.rsp.lists.list | if type == "array" then .[] else [.] end | "\(.name) (ID: \(.id))"' 2>/dev/null
else
  echo "❌ Error: $(echo "$RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
fi
```

## Helper Script

```bash
#!/bin/bash
# rtm_add_task.sh - Add task with tags

export RTM_API_KEY="$RTM_API_KEY"
export RTM_SHARED_SECRET="$RTM_SHARED_SECRET"
export RTM_AUTH_TOKEN="$RTM_AUTH_TOKEN"

TASK_NAME="$1"
TAGS="$2"  # Comma-separated, e.g., "shopping,urgent"

# Create timeline
TIMELINE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.timelines.create" | md5sum | cut -d' ' -f1)")

if ! echo "$TIMELINE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "❌ Failed to create timeline: $(echo "$TIMELINE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
  exit 1
fi

TIMELINE=$(echo "$TIMELINE" | jq -r '.rsp.timeline')

# Add task
ENCODED_NAME=$(printf '%s' "$TASK_NAME" | jq -sRr @uri | tr -d '\n')
SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.tasks.addname${TASK_NAME}timeline${TIMELINE}"
API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.add&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&name=${ENCODED_NAME}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

if ! echo "$RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
  echo "❌ Error adding task: $(echo "$RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
  exit 1
fi

LIST_ID=$(echo "$RESPONSE" | jq -r '.rsp.list.id // empty' 2>/dev/null)
TASKSERIES_ID=$(echo "$RESPONSE" | jq -r '.rsp.list.taskseries | if type == "array" then .[0] else . end | .id' 2>/dev/null)
TASK_ID=$(echo "$RESPONSE" | jq -r '.rsp.list.taskseries | if type == "array" then .[0] else . end | .task | if type == "array" then .[0] else . end | .id' 2>/dev/null)

echo "✅ Task added: $(echo "$RESPONSE" | jq -r '.rsp.list.taskseries | if type == "array" then .[0] else . end | .name' 2>/dev/null)"

# Add tags if provided
if [ -n "$TAGS" ]; then
  SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonlist_id${LIST_ID}methodrtm.tasks.addTagstags${TAGS}task_id${TASK_ID}taskseries_id${TASKSERIES_ID}timeline${TIMELINE}"
  API_SIG=$(printf '%s' "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)
  
  TAG_RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.addTags&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&list_id=${LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&tags=${TAGS}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")
  
  if echo "$TAG_RESPONSE" | jq -e '.rsp.stat == "ok"' >/dev/null 2>&1; then
    echo "🏷️ Tags added: $TAGS"
  else
    echo "⚠️ Failed to add tags: $(echo "$TAG_RESPONSE" | jq -r '.rsp.err.msg // "Unknown error"' 2>/dev/null)"
  fi
fi
```
Usage: `./rtm_add_task.sh "Buy milk" "shopping,urgent"`
