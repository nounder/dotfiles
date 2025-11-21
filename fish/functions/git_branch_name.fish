function git_branch_name -d "Get current git branch name, copy to clipboard if run directly"
    set -l branch (git branch --show-current 2>/dev/null)

    if test -z "$branch"
        return 1
    end

    echo $branch

    # If stdout is a TTY (not piped/not in command substitution), copy to clipboard
    if isatty stdout
        echo $branch | pbcopy
        echo "copied to clipboard" >&2
    end
end
