function git_default_branch --description "Get the default branch (main/master)"
    # Try to get the default branch from remote HEAD
    set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

    # If that fails, try to detect main or master locally
    if test -z "$default_branch"
        if git show-ref --verify --quiet refs/heads/main
            set default_branch main
        else if git show-ref --verify --quiet refs/heads/master
            set default_branch master
        else
            echo "Error: Could not determine default branch" >&2
            return 1
        end
    end

    echo $default_branch
end
