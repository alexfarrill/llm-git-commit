#!/bin/bash

# Script to generate commit message

# Check if .llm-system-prompt file exists
if [ ! -f .llm-system-prompt ]; then
    echo ".llm-system-prompt file not found in the current directory."
    exit 1
fi

# Read the content of .llm-system-prompt file
system_prompt=$(cat .llm-system-prompt)

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

