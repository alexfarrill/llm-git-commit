#!/bin/bash

# Script to generate commit message

# Traverse up directories to find the .llm-system-prompt file and read its content
file_name=".llm-system-prompt"
current_dir="$PWD"

while [ "$current_dir" != "/" ]; do
  if [ -f "$current_dir/$file_name" ]; then
    system_prompt=$(cat "$current_dir/$file_name")
    break
  fi
  current_dir=$(dirname "$current_dir")
done

if [ -z "$system_prompt" ]; then
  echo "File .llm-system-prompt not found."
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

