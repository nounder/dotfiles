function git_tree_enter
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository" >&2
        return 1
    end

    # If we're inside a worktree, cd into the original repo first
    set -l git_dir (git rev-parse --git-dir)
    set -l git_common_dir (git rev-parse --git-common-dir)

    # Make paths absolute
    if not string match -qr '^/' -- $git_dir
        set git_dir "$PWD/$git_dir"
    end
    if not string match -qr '^/' -- $git_common_dir
        set git_common_dir "$PWD/$git_common_dir"
    end

    # Check if we're in a worktree by comparing git-dir with git-common-dir
    if test "$git_dir" != "$git_common_dir"
        set -l repo_root_from_common (dirname $git_common_dir)
        if not test -d "$repo_root_from_common"
            echo "Error: Could not locate original git repository" >&2
            return 1
        end
        # Calculate relative path using string manipulation
        set -l current_path (pwd)
        set -l relative_wt (string replace -r "^$repo_root_from_common/" "" "$current_path")
        echo "Currently in worktree '$relative_wt'"
        echo "cd into main repo '$repo_root_from_common'"
        cd "$repo_root_from_common" >/dev/null
        if not test $status -eq 0
            echo "Error: Failed to cd into main repo" >&2
            return 1
        end
    end

    # Get the git repository root (should now be the original repo if we were in a worktree)
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
        # No branch name provided, just stay in main repo
        return 0
    end

    set branch_name $argv[1]

    # Check if branch exists
    if not git show-ref --verify --quiet "refs/heads/$branch_name"
        echo "Error: Branch '$branch_name' does not exist" >&2
        return 1
    end

    # CD into the worktree directory
    set worktree_path "$tree_dir/$branch_name"

    # Check if we're already in the target worktree
    set -l current_path (pwd)
    if string match -q "$worktree_path*" "$current_path"
        echo "Already in worktree '$branch_name'"
        return 0
    end
    if not test -d "$worktree_path"
        set -l worktree_parent (dirname $worktree_path)
        mkdir -p "$worktree_parent"
        set -l relative_wt (string replace -r "^$repo_root/" "" "$worktree_path")
        echo "Creating worktree at '$relative_wt'"

        # Create worktree with existing branch
        if not git worktree add "$worktree_path" "$branch_name"
            echo "Error: Failed to create worktree" >&2
            return 1
        end
    end
    set -l relative_wt (string replace -r "^$repo_root/" "" "$worktree_path")
    echo "cd into worktree '$relative_wt'"
    cd "$worktree_path" >/dev/null
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
