c() {
    if ! git diff --cached | grep -q . ; then
        echo "No changes to commit."
        return 1
    fi

    local msg=""
    local file_name="generate_commit_message.sh"
    local current_dir="$PWD"
    local script_path=""

    while [ "$current_dir" != "/" ]; do
        if [ -f "$current_dir/$file_name" ]; then
            script_path="$current_dir/$file_name"
            break
        fi
        current_dir=$(dirname "$current_dir")
    done

    if [ -n "$script_path" ]; then
        # Call the external script and pass all arguments
        msg=$("$script_path" "$@")
    else
        echo "generate_commit_message.sh script not found."
        git commit
    fi

    if [ -z "$msg" ]; then
        return 1 # Exit if the message is empty or script exits with error
    fi

    # Start an interactive commit with the pre-populated message
    git commit -m "$msg" -e
}

