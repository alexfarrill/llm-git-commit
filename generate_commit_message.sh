#!/bin/bash

# Script to generate commit message

# Traverse up directories to find the .llm-git-commit.yml file and read its content
config_file=".llm-git-commit.yml"
current_dir="$PWD"
config_path=""
system_prompt=""
api_key=""
model=""

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

llm_args=(-m "$model" -s "$hint $system_prompt")
if [ -n "$api_key" ]; then
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

  msg=$(printf "%s" "$diff" | llm "${llm_args[@]}")
fi
if [ -z "$msg" ]; then
    echo "Commit message is empty. Aborting commit."
    exit 1
fi

echo "$msg"
