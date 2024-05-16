# git commit with llm
c() {
    if ! git diff --cached | grep -q . ; then
        echo "No changes to commit."
        return 1
    fi

    local msg=""
    if [ -f ./generate_commit_message.sh ]; then
        # Call the external script and pass all arguments
        msg=$(./generate_commit_message.sh "$@")
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
