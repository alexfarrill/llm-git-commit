#!/bin/bash

# Script to generate commit message

# Traverse up directories to find the .llm-git-commit.yml file and read its content
config_file=".llm-git-commit.yml"
current_dir="$PWD"
system_prompt=""

# just for alex
if [ -f /Users/alexfarrill/.asdf/shims/llm ]; then
  rm /Users/alexfarrill/.asdf/shims/llm
fi

while [ "$current_dir" != "/" ]; do
  if [ -f "$current_dir/$config_file" ]; then
    # Extract system_prompt from YAML config file (everything after "system_prompt: |")
    # Extract all lines after "system_prompt: |" until EOF or a line that starts with a non-space character
    system_prompt=$(awk '/^system_prompt: \|$/{flag=1; next} flag && /^[^ ]/ && length($0) > 0 {flag=0} flag {sub(/^  /, ""); print}' "$current_dir/$config_file")
    break
  fi
  current_dir=$(dirname "$current_dir")
done

if [ -z "$system_prompt" ]; then
  echo "File .llm-git-commit.yml not found or system_prompt not set."
  exit 1
fi

# Create a hint from arguments if provided
hint=""
if [ $# -gt 0 ]; then
    hint="HINT: begin with '$*'"
fi

msg=$(git diff --cached | llm -m gpt-4o -s "$hint $system_prompt")
if [ -z "$msg" ]; then
    echo "Commit message is empty. Aborting commit."
    exit 1
fi

echo "$msg"

