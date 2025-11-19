function git_tree_enter
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository" >&2
        return 1
    end

    # Get the git repository root
    set repo_root (git rev-parse --show-toplevel)

    # Check if tree directory exists
    set tree_dir "$repo_root/tree"
    if not test -d "$tree_dir"
        read -P "The 'tree' directory does not exist. Create it? (y/n) " -n 1 response
        echo
        if not string match -qi "y" $response
            echo "Exiting without creating tree directory."
            return 0
        end
        mkdir -p "$tree_dir"
        echo "Created tree directory at $tree_dir"
    end

    # Check if branch name argument is provided
    if test (count $argv) -eq 0
        echo "Error: Branch name required as first argument" >&2
        return 1
    end

    set branch_name $argv[1]

    # Check if branch exists
    if not git rev-parse --verify "$branch_name" >/dev/null 2>&1
        echo "Branch '$branch_name' not found locally. Fetching from remote..."
        git fetch

        # Try again after fetch
        if not git rev-parse --verify "$branch_name" >/dev/null 2>&1
            echo "Error: Branch '$branch_name' does not exist" >&2
            return 1
        end
    end

    # CD into the worktree directory
    set worktree_path "$tree_dir/$branch_name"
    cd "$worktree_path"
end

# Get list of all git branches for autocomplete
function __git_tree_enter_branches
    git branch --all 2>/dev/null \
        | string trim \
        | string replace -r "^[*+] " "" \
        | string replace "remotes/origin/" "" \
        | grep -v "HEAD ->"
end

# Autocomplete for git_tree_enter - suggests all git branches
complete -c git_tree_enter -f -a '(__git_tree_enter_branches)'
