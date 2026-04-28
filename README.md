# llm-git-commit
writes your commit messages

# dependencies
- https://github.com/simonw/llm

# how to
1. install llm commandline and configure your keys
2. include llm-git-commit.zsh to your .zshrc (`source /path/to/llm-git-commit.zsh`)
3. go to your project directory and *from there* run the install.sh script (or copy the .sh and .llm-system-prompt files to your project)
4. when you're ready to commit code, type `c`

## api key
By default, this uses `OPENAI_API_KEY` when it is set. Otherwise, it falls back to the `openai` key configured in the `llm` CLI.

## model
By default, this uses `gpt-4o`. Override it in `.llm-git-commit.yml`:

```yaml
model: gpt-4o
```

## lockfiles
Lockfiles like `yarn.lock` and `Gemfile.lock` are omitted from the diff sent to the model.

## large diffs
Deleted files are summarized by filename instead of sending the full removed content. If the remaining diff is larger than `120000` characters, the script stops instead of sending it to the model. Override that limit with `LLM_GIT_COMMIT_MAX_DIFF_CHARS`.

## advanced
type a hint after c to give the llm a hint, e.g.:
- hint temp
- hint deploy
- hint refactoring app directory
