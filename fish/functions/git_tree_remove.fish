function git_tree_remove
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository" >&2
        return 1
    end

    # Parse -f flag
    set -l force_flag 0
    set -l branch_name ""

    for arg in $argv
        if test "$arg" = "-f"
            set force_flag 1
        else
            set branch_name "$arg"
        end
    end

    # Get the git repository root and worktree info
    set -l git_dir (git rev-parse --git-dir)
    set -l git_common_dir (git rev-parse --git-common-dir)

    # Make paths absolute
    if not string match -r '^/' -- $git_dir
        set git_dir "$PWD/$git_dir"
    end
    if not string match -r '^/' -- $git_common_dir
        set git_common_dir "$PWD/$git_common_dir"
    end

    # Check if we're in a worktree
    set -l in_worktree 0
    set -l current_worktree_path ""
    if test "$git_dir" != "$git_common_dir"
        set in_worktree 1
        set current_worktree_path (git rev-parse --show-toplevel)
    end

    # Get the main repo root
    set -l repo_root (dirname $git_common_dir)

    # If no branch name provided and we're in a worktree, use current worktree
    if test -z "$branch_name"
        if test $in_worktree -eq 0
            echo "Error: Branch name required when not in a worktree" >&2
            return 1
        end
        set branch_name (git branch --show-current)
    end

    # Find the worktree path for the branch
    set -l worktree_path ""
    set -l worktree_info (git worktree list --porcelain | string match -r "(?s)worktree.*?branch refs/heads/$branch_name")

    if test -n "$worktree_info"
        set worktree_path (echo $worktree_info | string match -r "^worktree (.+)" | string split ' ')[2]
    else
        echo "Error: No worktree found for branch '$branch_name'" >&2
        return 1
    end

    # Check if working tree is clean (unless -f is passed)
    if test $force_flag -eq 0
        if test -n "$(git -C "$worktree_path" status --porcelain 2>/dev/null)"
            echo "Error: Working tree for '$branch_name' has uncommitted changes" >&2
            echo "Use -f to force removal" >&2
            return 1
        end
    end

    # If we're currently in the worktree to be removed, cd to main repo first
    if test "$current_worktree_path" = "$worktree_path"
        cd "$repo_root"

        # Prompt user for confirmation unless -f is passed
        if test $force_flag -eq 0
            read -P "Remove current worktree '$branch_name'? (y/n) " -n 1 response
            echo
            if not string match -qi "y" $response
                echo "Cancelled worktree removal."
                return 0
            end
        end
    end

    # Remove the worktree
    echo "Removing worktree for branch '$branch_name'..."
    if not git worktree remove "$worktree_path"
        echo "Error: Failed to remove worktree at $worktree_path" >&2
        return 1
    end

    echo "Worktree removed successfully."
end

# Get list of worktree branches for autocomplete
function __git_tree_remove_branches
    git worktree list --porcelain 2>/dev/null \
        | string match -r "^branch refs/heads/(.+)" \
        | string replace "branch refs/heads/" ""
end

# Autocomplete for git_tree_remove - suggests worktree branches and -f flag
complete -c git_tree_remove -f -a '(__git_tree_remove_branches)'
complete -c git_tree_remove -s f -d 'Force removal without prompts'
