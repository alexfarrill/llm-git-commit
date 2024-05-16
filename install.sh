#!/bin/bash

# Determine the directory where the script resides
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Check if the current working directory is the same as the script directory
if [ "${PWD}" == "${SCRIPT_DIR}" ]; then
  echo "Error: Invoke this script from the directory of the project where you'd like to create symlinks."
  exit 1
fi

# Create a symbolic link in the current working directory to .llm-system-prompt.default
ln -s "${SCRIPT_DIR}/.llm-system-prompt.default" "${PWD}/.llm-system-prompt"

# Create a symbolic link in the current working directory to generate_commit_message.sh
ln -s "${SCRIPT_DIR}/generate_commit_message.sh" "${PWD}/generate_commit_message.sh"

