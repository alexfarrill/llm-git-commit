# llm-git-commit
writes your commit messages

# dependencies
- https://github.com/simonw/llm

# how to
1. install llm commandline and configure your keys
2. include llm-git-commit.zsh to your .zshrc (`source /path/to/llm-git-commit.zsh`)
3. go to your project directory and *from there* run the install.sh script (or copy the .sh and .llm-system-prompt files to your project)
4. when you're ready to commit code, type `c`

## advanced
type a hint after c to give the llm a hint, e.g.:
- hint temp
- hint deploy
- hint refactoring app directory
