#!/bin/bash
set -x  # Debug tracing

# Configuration
OLLAMA_MODEL="mistral:7b"
OLLAMA_HOST="http://localhost:11434"
DEFAULT_TAG="feat"

# Ensure we are inside a Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not inside a Git repository."
    exit 1
fi

# Stage changes
git add .

# Get first 50 lines of diff
GIT_DIFF="$(git diff --cached)"
echo "$GIT_DIFF" > /tmp/git_diff_debug.log

if [ -z "$GIT_DIFF" ]; then
    echo "❌ No changes detected."
    exit 1
fi

# Gather metadata
BRANCH_NAME="$(git rev-parse --abbrev-ref HEAD)"
LAST_COMMITS="$(git log -3 --pretty=format:"- %s")"
CHANGED_FILES="$(git diff --cached --name-only)"

# Build a short prompt
read -r -d '' PROMPT <<EOF
Generate a concise Git commit message under 72 chars.
Use imperative mood, do NOT return "null". Only one short line.

Branch: $BRANCH_NAME
Recent commits:
$LAST_COMMITS
Changed files:
$CHANGED_FILES

Diff excerpt:
$GIT_DIFF
EOF

# Use jq to properly escape newlines and quotes
JSON_REQUEST="$(
  jq -Rs --arg model "$OLLAMA_MODEL" --arg prompt "$PROMPT" \
  '{model: $model, prompt: $prompt, stream: false}' <<< ""
)"

# Debug: Write request to disk
echo "$JSON_REQUEST" > /tmp/gitai_json_request.log
cat /tmp/gitai_json_request.log | jq .  # For debugging

echo "🔄 Calling Ollama API..."
RESPONSE="$(
  curl -s "$OLLAMA_HOST/api/generate" \
       -H "Content-Type: application/json" \
       -d @/tmp/gitai_json_request.log
)"

# Debug: Log raw response
echo "$RESPONSE" > /tmp/gitai_api_response.log
cat /tmp/gitai_api_response.log

# Extract commit message
COMMIT_MESSAGE="$(echo "$RESPONSE" | jq -r '.response' 2>/dev/null)"

# Retry if "null" or empty
if [[ -z "$COMMIT_MESSAGE" || "$COMMIT_MESSAGE" == "null" ]]; then
    echo "⚠️ Invalid commit message. Retrying once..."
    RESPONSE="$(
      curl -s "$OLLAMA_HOST/api/generate" \
           -H "Content-Type: application/json" \
           -d @/tmp/gitai_json_request.log
    )"
    echo "$RESPONSE" > /tmp/gitai_api_response.log
    COMMIT_MESSAGE="$(echo "$RESPONSE" | jq -r '.response' 2>/dev/null)"
fi

# Prompt user if AI fails
if [[ -z "$COMMIT_MESSAGE" || "$COMMIT_MESSAGE" == "null" ]]; then
    echo "❌ Ollama failed to generate a valid commit message."
    read -rp "📝 Enter commit message manually: " COMMIT_MESSAGE
fi

# Still empty? Abort
if [ -z "$COMMIT_MESSAGE" ]; then
    echo "❌ No commit message provided."
    exit 1
fi

# Prepend default tag
COMMIT_MESSAGE="$DEFAULT_TAG: $COMMIT_MESSAGE"

# Show final message
echo -e "\n📝 Suggested commit message:\n----------------------------------------\n$COMMIT_MESSAGE\n----------------------------------------"
read -rp "🛠️  Use this commit message? (y/n/edit): " CONFIRM

if [[ "$CONFIRM" == "n" ]]; then
    echo "❌ Commit aborted."
    exit 1
elif [[ "$CONFIRM" == "edit" ]]; then
    echo "$COMMIT_MESSAGE" > /tmp/git_commit_msg.txt
    ${EDITOR:-nano} /tmp/git_commit_msg.txt
    COMMIT_MESSAGE="$(cat /tmp/git_commit_msg.txt)"
fi

# Commit and push
git commit -m "$COMMIT_MESSAGE"
git push
echo "✅ Commit and push successful!"
