#!/bin/bash

# Script to generate commit message

# Traverse up directories to find the .llm-git-commit.yml file and read its content
config_file=".llm-git-commit.yml"
current_dir="$PWD"
config_path=""
system_prompt=""
api_key=""
model=""
priority=""
priority_enabled=""

read_yaml_scalar() {
  local key="$1"
  local file="$2"

  awk -F': *' -v key="$key" '
    $1 == key {
      sub("^[^:]*:[[:space:]]*", "")
      sub("[[:space:]]*#.*$", "")
      sub("^[[:space:]]*[\"'\'']?", "")
      sub("[\"'\'']?[[:space:]]*$", "")
      print
      exit
    }
  ' "$file"
}

# just for alex
if [ -f /Users/alexfarrill/.asdf/shims/llm ]; then
  rm /Users/alexfarrill/.asdf/shims/llm
fi

while [ "$current_dir" != "/" ]; do
  if [ -f "$current_dir/$config_file" ]; then
    config_path="$current_dir/$config_file"
    # Extract system_prompt from YAML config file (everything after "system_prompt: |")
    # Extract all lines after "system_prompt: |" until EOF or a line that starts with a non-space character
    system_prompt=$(awk '/^system_prompt: \|$/{flag=1; next} flag && /^[^ ]/ && length($0) > 0 {flag=0} flag {sub(/^  /, ""); print}' "$config_path")
    model=$(read_yaml_scalar "model" "$config_path")
    priority=$(read_yaml_scalar "priority" "$config_path")
    break
  fi
  current_dir=$(dirname "$current_dir")
done

if [ -z "$system_prompt" ]; then
  echo "File .llm-git-commit.yml not found or system_prompt not set."
  exit 1
fi

if [ -n "$OPENAI_API_KEY" ]; then
  api_key="$OPENAI_API_KEY"
fi

# Create a hint from arguments if provided
hint=""
if [ $# -gt 0 ]; then
    hint="HINT: begin with '$*'"
fi

if [ -z "$model" ]; then
  model="gpt-4o"
fi

if [ -z "$priority" ]; then
  priority="true"
fi

case "$priority" in
  true|yes|1|on)
    priority_enabled="1"
    ;;
  false|no|0|off)
    priority_enabled="0"
    ;;
  *)
    echo "priority must be true or false."
    exit 1
    ;;
esac

llm_args=(-m "$model" -s "$hint $system_prompt")
if [ "$priority_enabled" = "0" ] && [ -n "$api_key" ]; then
  llm_args+=(--key "$api_key")
fi

diff_pathspecs=(
  .
  ":(exclude)yarn.lock"
  ":(exclude,glob)**/yarn.lock"
  ":(exclude)Gemfile.lock"
  ":(exclude,glob)**/Gemfile.lock"
)

content_diff=$(git diff --cached --diff-filter=ACMRTUXB -- "${diff_pathspecs[@]}")
deleted_files=$(git diff --cached --diff-filter=D --name-only -- "${diff_pathspecs[@]}")

diff="$content_diff"
if [ -n "$deleted_files" ]; then
  deleted_summary=$(printf "%s\n" "$deleted_files" | sed "s/^/- /")
  if [ -n "$diff" ]; then
    diff="${diff}"$'\n\n'
  fi
  diff="${diff}Deleted files:"$'\n'"${deleted_summary}"
fi

if [ -z "$diff" ]; then
  msg="Update lockfiles"
else
  max_diff_chars="${LLM_GIT_COMMIT_MAX_DIFF_CHARS:-120000}"
  if ! [[ "$max_diff_chars" =~ ^[0-9]+$ ]]; then
    echo "LLM_GIT_COMMIT_MAX_DIFF_CHARS must be a positive integer."
    exit 1
  fi

  diff_chars=$(printf "%s" "$diff" | wc -c | tr -d " ")
  if [ "$diff_chars" -gt "$max_diff_chars" ]; then
    echo "Diff is too large for llm-git-commit ($diff_chars chars > $max_diff_chars)."
    echo "Commit manually or raise LLM_GIT_COMMIT_MAX_DIFF_CHARS."
    exit 1
  fi

  if [ "$priority_enabled" = "1" ] && ! command -v jq >/dev/null 2>&1; then
    echo "priority: true requires jq to build and parse OpenAI API JSON."
    exit 1
  fi

  if [ "$priority_enabled" = "1" ] && [ -z "$api_key" ]; then
    api_key=$(llm keys get openai 2>/dev/null || true)
  fi

  if [ "$priority_enabled" = "1" ] && [ -z "$api_key" ]; then
    echo "priority: true requires OPENAI_API_KEY or an openai key configured in llm."
    exit 1
  fi

  start_time=$(date +%s)
  output_file=$(mktemp)
  status_file=$(mktemp)
  if [ "$priority_enabled" = "1" ]; then
    echo -n "Generating commit message with $model using OpenAI priority processing " >&2
  else
    echo -n "Generating commit message with $model using OPENAI_API_KEY " >&2
  fi
  (
    if [ "$priority_enabled" = "1" ]; then
      response_file=$(mktemp)
      http_status=$(
        jq -n \
          --arg model "$model" \
          --arg system "$hint $system_prompt" \
          --arg input "$diff" \
          '{
            model: $model,
            service_tier: "priority",
            messages: [
              {role: "system", content: $system},
              {role: "user", content: $input}
            ]
          }' |
        curl -sS -o "$response_file" -w "%{http_code}" \
          https://api.openai.com/v1/chat/completions \
          -H "Authorization: Bearer $api_key" \
          -H "Content-Type: application/json" \
          -d @-
      )
      curl_status=$?
      if [ "$curl_status" -ne 0 ]; then
        rm -f "$response_file"
        echo "$curl_status" >"$status_file"
        exit
      fi
      if [[ "$http_status" != 2* ]]; then
        cat "$response_file" >&2
        rm -f "$response_file"
        echo 1 >"$status_file"
        exit
      fi
      jq -r '.choices[0].message.content // empty' "$response_file" >"$output_file"
      jq_status=$?
      rm -f "$response_file"
      if [ "$jq_status" -ne 0 ]; then
        echo "$jq_status" >"$status_file"
        exit
      fi
    else
      printf "%s" "$diff" | llm "${llm_args[@]}" >"$output_file"
    fi
    echo $? >"$status_file"
  ) &
  llm_pid=$!
  spinner='|/-\'
  spinner_index=0
  while kill -0 "$llm_pid" 2>/dev/null; do
    if [ "$priority_enabled" = "1" ]; then
      printf "\rGenerating commit message with %s using OpenAI priority processing %s" "$model" "${spinner:$spinner_index:1}" >&2
    else
      printf "\rGenerating commit message with %s using OPENAI_API_KEY %s" "$model" "${spinner:$spinner_index:1}" >&2
    fi
    spinner_index=$(((spinner_index + 1) % 4))
    sleep 0.2
  done
  wait "$llm_pid"
  if [ "$priority_enabled" = "1" ]; then
    printf "\rGenerating commit message with %s using OpenAI priority processing done\n" "$model" >&2
  else
    printf "\rGenerating commit message with %s using OPENAI_API_KEY done\n" "$model" >&2
  fi

  msg=$(cat "$output_file")
  llm_status=$(cat "$status_file")
  rm -f "$output_file" "$status_file"
  elapsed=$(($(date +%s) - start_time))

  if [ "$llm_status" -ne 0 ]; then
    echo "Commit message generation failed after ${elapsed}s." >&2
    exit "$llm_status"
  fi

  echo "Generated commit message in ${elapsed}s." >&2
fi
if [ -z "$msg" ]; then
    echo "Commit message is empty. Aborting commit."
    exit 1
fi

echo "$msg"
