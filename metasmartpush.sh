#!/bin/bash
set -e

echo "🔄 Fetching available models from Ollama..."
OLLAMA_HOST="http://localhost:11434"
MODEL_LIST_RESPONSE="$(curl -s "$OLLAMA_HOST/api/tags")"

if [[ -z "$MODEL_LIST_RESPONSE" || "$MODEL_LIST_RESPONSE" == "null" ]]; then
    echo "❌ No response from Ollama. Ensure the server is running!"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "❌ 'jq' is required but not installed."
    exit 1
fi

declare -A MODEL_MAP
MODELS=($(echo "$MODEL_LIST_RESPONSE" | jq -r '.models[].name'))
if [[ ${#MODELS[@]} -eq 0 ]]; then
    echo "❌ No models found on Ollama server."
    exit 1
fi

for MODEL in "${MODELS[@]}"; do
    SAFE_NAME="$(echo "$MODEL" | sed 's/[^a-zA-Z0-9]/_/g')"
    MODEL_MAP["$SAFE_NAME"]="$MODEL"
done

echo "✅ Models available: ${MODELS[*]}"

# Check Git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not inside a Git repository."
    exit 1
fi

git add .
GIT_DIFF="$(git diff --cached | head -n 50)"
if [ -z "$GIT_DIFF" ]; then
    echo "❌ No changes detected."
    exit 1
fi

BRANCH_NAME="$(git rev-parse --abbrev-ref HEAD)"
LAST_COMMITS="$(git log -3 --pretty=format:"- %s")"
CHANGED_FILES="$(git diff --cached --name-only)"

# --- Use cat <<EOF instead of read -r -d ''
PROMPT="$(cat <<EOF
Generate a concise Git commit message under 72 characters, in imperative mood.

Branch: $BRANCH_NAME
Recent commits:
$LAST_COMMITS
Changed files:
$CHANGED_FILES

Diff excerpt:
$GIT_DIFF
EOF
)"

# convert prompt to JSON
JSON_PROMPT="$(jq -Rs --arg prompt "$PROMPT" '{prompt: $prompt, stream: false}' <<< "")"

echo "🚀 Running AI models for commit message suggestions..."
declare -A COMMIT_MESSAGES
declare -A RESPONSE_TIMES

for SAFE_NAME in "${!MODEL_MAP[@]}"; do
    API_MODEL="${MODEL_MAP[$SAFE_NAME]}"
    echo "🔍 Running: $API_MODEL"

    JSON_REQUEST="$(jq --arg model "$API_MODEL" '. + {model: $model}' <<< "$JSON_PROMPT")"
    echo "$JSON_REQUEST" > /tmp/gitai_request.json

    START_TIME=$(date +%s.%N)
    RESPONSE="$(curl -s "$OLLAMA_HOST/api/generate" -H "Content-Type: application/json" -d @/tmp/gitai_request.json)"
    END_TIME=$(date +%s.%N)
    ELAPSED_TIME=$(echo "$END_TIME - $START_TIME" | bc)

    COMMIT_MESSAGE="$(echo "$RESPONSE" | jq -r '.response' | head -n 1 | cut -c -72)"
    if [[ -z "$COMMIT_MESSAGE" || "$COMMIT_MESSAGE" == "null" ]]; then
        COMMIT_MESSAGE="⚠️ No valid response"
    fi

    COMMIT_MESSAGES["$SAFE_NAME"]="$COMMIT_MESSAGE"
    RESPONSE_TIMES["$SAFE_NAME"]="$ELAPSED_TIME"

    echo "✔️ [$API_MODEL] ⏳ ${ELAPSED_TIME}s → $COMMIT_MESSAGE"
done

echo "✅ Benchmark complete!"
echo "📊 Summary of AI-generated commit messages:"
i=1
declare -A MODEL_INDEX
for SAFE_NAME in "${!MODEL_MAP[@]}"; do
    API_MODEL="${MODEL_MAP[$SAFE_NAME]}"
    echo "$i) [$API_MODEL] ⏳ ${RESPONSE_TIMES[$SAFE_NAME]}s"
    echo "   💡 ${COMMIT_MESSAGES[$SAFE_NAME]}"
    echo "----------------------------------------"
    MODEL_INDEX["$i"]="$SAFE_NAME"
    ((i++))
done

echo "🔢 Select commit message number (or 0 to abort):"
read -rp "Enter choice: " CHOICE

if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || [[ "$CHOICE" -lt 0 ]] || [[ "$CHOICE" -gt ${#MODEL_MAP[@]} ]]; then
    echo "❌ Invalid choice. Aborting."
    exit 1
fi

if [[ "$CHOICE" -eq 0 ]]; then
    echo "❌ Commit aborted."
    exit 1
fi

SELECTED_MODEL="${MODEL_INDEX[$CHOICE]}"
SELECTED_COMMIT_MESSAGE="${COMMIT_MESSAGES[$SELECTED_MODEL]}"

echo -e "\n📝 Final commit message:\n----------------------------------------"
echo "$SELECTED_COMMIT_MESSAGE"
echo "----------------------------------------"
read -rp "🛠️  Use this commit message? (y/n/edit): " CONFIRM

if [[ "$CONFIRM" == "n" ]]; then
    echo "❌ Commit aborted."
    exit 1
elif [[ "$CONFIRM" == "edit" ]]; then
    echo "$SELECTED_COMMIT_MESSAGE" > /tmp/git_commit_msg.txt
    ${EDITOR:-nano} /tmp/git_commit_msg.txt
    SELECTED_COMMIT_MESSAGE="$(cat /tmp/git_commit_msg.txt)"
fi

if [ -z "$SELECTED_COMMIT_MESSAGE" ]; then
    echo "❌ No commit message provided."
    exit 1
fi

git commit -m "$SELECTED_COMMIT_MESSAGE"
git push
echo "✅ Commit and push successful!"
