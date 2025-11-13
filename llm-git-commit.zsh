c() {
    if ! git diff --cached | grep -q . ; then
        echo "No changes to commit."
        return 1
    fi

    local msg=""
    local config_file=".llm-git-commit.yml"
    local current_dir="$PWD"
    local script_path=""

    # Traverse up directories to find the config file
    while [ "$current_dir" != "/" ]; do
        if [ -f "$current_dir/$config_file" ]; then
            # Extract script_path from YAML config file
            script_path=$(grep "^script_path:" "$current_dir/$config_file" | sed 's/^script_path:[[:space:]]*//' | sed 's/[[:space:]]*$//')
            break
        fi
        current_dir=$(dirname "$current_dir")
    done

    if [ -z "$script_path" ] || [ ! -f "$script_path" ]; then
        echo "generate_commit_message.sh script not found. Please set script_path in .llm-git-commit.yml"
        git commit
        return 1
    fi

    # Call the external script and pass all arguments
    msg=$("$script_path" "$@")

    if [ -z "$msg" ]; then
        return 1 # Exit if the message is empty or script exits with error
    fi

    # Start an interactive commit with the pre-populated message
    git commit -m "$msg" -e
}

