function git_tree_enter
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository" >&2
        return 1
    end

    # If we're inside a worktree, operate from the primary repo instead
    set -l git_dir (git rev-parse --git-dir)
    set -l git_common_dir (git rev-parse --git-common-dir)
    if not string match -r '^/' -- $git_dir
        set git_dir "$PWD/$git_dir"
    end
    if not string match -r '^/' -- $git_common_dir
        set git_common_dir "$PWD/$git_common_dir"
    end
    if test "$git_dir" != "$git_common_dir"
        set -l repo_root_from_common (dirname $git_common_dir)
        if not test -d "$repo_root_from_common"
            echo "Error: Could not locate original git repository" >&2
            return 1
        end
        cd "$repo_root_from_common"
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

    # CD into the worktree directory
    set worktree_path "$tree_dir/$branch_name"
    if not test -d "$worktree_path"
        set -l worktree_parent (dirname $worktree_path)
        mkdir -p "$worktree_parent"
        echo "Creating worktree at $worktree_path"

        # Try to create worktree with existing branch
        if not git worktree add "$worktree_path" "$branch_name" 2>/dev/null
            # Branch doesn't exist, create it from current HEAD
            echo "Branch '$branch_name' doesn't exist. Creating new branch..."
            if not git worktree add -b "$branch_name" "$worktree_path"
                echo "Error: Failed to create worktree at $worktree_path" >&2
                return 1
            end
        end
    end
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
