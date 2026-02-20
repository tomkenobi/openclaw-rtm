# RTM (Remember The Milk) Skill

Manage your [Remember The Milk](https://www.rememberthemilk.com/) tasks directly from OpenClaw. Add tasks, check lists, set due dates, complete items, and organize your to-dos – all via the RTM REST API.

## Quickstart

1) Env vars setzen (`~/.openclaw/.env`):

```bash
RTM_API_KEY=...
RTM_SHARED_SECRET=...
RTM_AUTH_TOKEN=...
RTM_USERNAME=...   # optional (nur falls du es irgendwo nutzt)
```

2) Scripts ausführbar machen (falls nötig):

```bash
chmod +x ./scripts/*.sh
```

3) Listen anzeigen:

```bash
./scripts/rtm_lists.sh
```

4) Heute fällige Tasks:

```bash
./scripts/rtm_list.sh 'due:today'
```

5) Task anlegen:

```bash
./scripts/rtm_add_task.sh "Buy milk" "shopping"
```

## Setup

### 1. Get API Credentials

1. Go to https://www.rememberthemilk.com/services/api/
2. Request an API key (requires RTM Pro account)
3. Note down your **API Key** and **Shared Secret**

### 2. Authenticate

You need an auth token to access your account:

```bash
# Step 1: Get a frob
FROB=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.auth.getFrob&api_key=YOUR_API_KEY&format=json&api_sig=YOUR_SIG" | jq -r '.rsp.frob')

# Step 2: Open browser for authorization
echo "Visit: https://www.rememberthemilk.com/services/auth/?api_key=YOUR_API_KEY&perms=delete&frob=$FROB"
# Click "Authorize" in the browser

# Step 3: Get auth token
TOKEN=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.auth.getToken&api_key=YOUR_API_KEY&format=json&frob=$FROB&api_sig=YOUR_SIG" | jq -r '.rsp.auth.token')
echo "Your token: $TOKEN"
```

### 3. Configure Environment

Add to your `~/.openclaw/.env`:

```bash
RTM_API_KEY=your_api_key_here
RTM_SHARED_SECRET=your_shared_secret_here
RTM_AUTH_TOKEN=your_auth_token_here
RTM_USERNAME=your_rtm_username  # optional (nur falls du es irgendwo nutzt)
```

## Usage Examples

### List All Tasks
```bash
RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&filter=status:incomplete&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}filterstatus:incompleteformatjsonmethodrtm.tasks.getList" | md5sum | cut -d' ' -f1)")

echo "$RESPONSE" | jq -r '.rsp.tasks.list | if type == "array" then .[] else [.] end | .taskseries | if type == "array" then .[] else [.] end | .name' 2>/dev/null
```

### Add a Task
```bash
# Create timeline
TIMELINE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.timelines.create" | md5sum | cut -d' ' -f1)" | jq -r '.rsp.timeline')

# Add task
TASK_NAME="Buy milk"
SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.tasks.addname${TASK_NAME}timeline${TIMELINE}"
API_SIG=$(echo -n "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.add&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&name=$(echo "$TASK_NAME" | jq -sRr @uri)&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}"
```

### Complete a Task
```bash
# First find task IDs (list_id, taskseries_id, task_id required)
SEARCH_RESULT=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&filter=name:milk&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}filtername:milkformatjsonmethodrtm.tasks.getList" | md5sum | cut -d' ' -f1)")

LIST_ID=$(echo "$SEARCH_RESULT" | jq -r '.rsp.tasks.list | if type == "array" then .[0] else . end | .id' 2>/dev/null)
TASKSERIES_ID=$(echo "$SEARCH_RESULT" | jq -r '.rsp.tasks.list | if type == "array" then .[0] else . end | .taskseries | if type == "array" then .[0] else . end | .id' 2>/dev/null)
TASK_ID=$(echo "$SEARCH_RESULT" | jq -r '.rsp.tasks.list | if type == "array" then .[0] else . end | .taskseries | if type == "array" then .[0] else . end | .task | if type == "array" then .[0] else . end | .id' 2>/dev/null)

# Complete it
SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonlist_id${LIST_ID}methodrtm.tasks.completetask_id${TASK_ID}taskseries_id${TASKSERIES_ID}timeline${TIMELINE}"
API_SIG=$(echo -n "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.complete&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&list_id=${LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}"
```

### Set Due Date
```bash
DUE_DATE="2026-02-20"
SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}due${DUE_DATE}formatjsonlist_id${LIST_ID}methodrtm.tasks.setDueDatetask_id${TASK_ID}taskseries_id${TASKSERIES_ID}timeline${TIMELINE}"
API_SIG=$(echo -n "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.setDueDate&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&list_id=${LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&due=${DUE_DATE}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}"
```

### Add Tags to Task
```bash
TAGS="shopping,urgent"
SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonlist_id${LIST_ID}methodrtm.tasks.addTagstags${TAGS}task_id${TASK_ID}taskseries_id${TASKSERIES_ID}timeline${TIMELINE}"
API_SIG=$(echo -n "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.addTags&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&list_id=${LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&tags=${TAGS}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}"
```

### Filter Tasks
```bash
# Today's tasks
FILTER="due:today"

# Overdue tasks
FILTER="dueBefore:today"

# Tasks by tag
FILTER="tag:shopping"

# Tasks from specific list
FILTER="list:Inbox"

RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.getList&api_key=${RTM_API_KEY}&format=json&filter=${FILTER}&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}filter${FILTER}formatjsonmethodrtm.tasks.getList" | md5sum | cut -d' ' -f1)")
```

### Manage Lists
```bash
# Get all lists
RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.lists.getList&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.lists.getList" | md5sum | cut -d' ' -f1)")
echo "$RESPONSE" | jq -r '.rsp.lists.list | if type == "array" then .[] else [.] end | "\(.name) (ID: \(.id))"' 2>/dev/null

# Create new list
LIST_NAME="Projects"
SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.lists.addname${LIST_NAME}timeline${TIMELINE}"
API_SIG=$(echo -n "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.lists.add&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&name=${LIST_NAME}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}"
```

## API Notes

- **Rate Limit**: 1 call per second recommended
- **Authentication**: Token doesn't expire unless revoked
- **Smart Add**: RTM API does NOT parse Smart Add syntax (like `#tag` or `^date`) in task names. Use separate API calls for tags, due dates, and priorities
- **Task IDs**: RTM uses 3 IDs per task: `list_id`, `taskseries_id`, `task_id`
- **Signatures**: All API calls require MD5 signatures of sorted parameters
- **Timelines**: Required for write operations (create once, reuse for batch operations)

## Helper Script

Save as `rtm_add_task.sh`:

```bash
#!/bin/bash
# Add task with tags to RTM

TASK_NAME="$1"
TAGS="$2"

# Create timeline
TIMELINE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.timelines.create&api_key=${RTM_API_KEY}&format=json&auth_token=${RTM_AUTH_TOKEN}&api_sig=$(echo -n "${RTM_SHARED_SECRET}api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.timelines.create" | md5sum | cut -d' ' -f1)" | jq -r '.rsp.timeline')

# Add task
SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonmethodrtm.tasks.addname${TASK_NAME}timeline${TIMELINE}"
API_SIG=$(echo -n "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)

RESPONSE=$(curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.add&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&name=$(echo "$TASK_NAME" | jq -sRr @uri)&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}")

LIST_ID=$(echo "$RESPONSE" | jq -r '.rsp.list.id // empty' 2>/dev/null)
TASKSERIES_ID=$(echo "$RESPONSE" | jq -r '.rsp.list.taskseries | if type == "array" then .[0] else . end | .id' 2>/dev/null)
TASK_ID=$(echo "$RESPONSE" | jq -r '.rsp.list.taskseries | if type == "array" then .[0] else . end | .task | if type == "array" then .[0] else . end | .id' 2>/dev/null)

echo "✅ Added: $(echo "$RESPONSE" | jq -r '.rsp.list.taskseries | if type == "array" then .[0] else . end | .name' 2>/dev/null)"

# Add tags if provided
if [ -n "$TAGS" ]; then
  SIG_STRING="api_key${RTM_API_KEY}auth_token${RTM_AUTH_TOKEN}formatjsonlist_id${LIST_ID}methodrtm.tasks.addTagstags${TAGS}task_id${TASK_ID}taskseries_id${TASKSERIES_ID}timeline${TIMELINE}"
  API_SIG=$(echo -n "${RTM_SHARED_SECRET}${SIG_STRING}" | md5sum | cut -d' ' -f1)
  curl -s "https://api.rememberthemilk.com/services/rest/?method=rtm.tasks.addTags&api_key=${RTM_API_KEY}&format=json&timeline=${TIMELINE}&list_id=${LIST_ID}&taskseries_id=${TASKSERIES_ID}&task_id=${TASK_ID}&tags=${TAGS}&auth_token=${RTM_AUTH_TOKEN}&api_sig=${API_SIG}" > /dev/null
  echo "🏷️ Tags: $TAGS"
fi
```

Usage: `./rtm_add_task.sh "Buy milk" "shopping,urgent"`

## Resources

- [RTM API Documentation](https://www.rememberthemilk.com/services/api/)
- [RTM API Methods](https://www.rememberthemilk.com/services/api/methods/)
- [RTM Smart Add](https://www.rememberthemilk.com/help/answer/207-smartadd) (web only, not API)
