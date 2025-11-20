function git_tree_remove
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository" >&2
        return 1
    end

    # Parse flags
    set -l force_flag 0
    set -l delete_branch 0
    set -l branch_name ""

    for arg in $argv
        if test "$arg" = "-f"
            set force_flag 1
        else if test "$arg" = "-d"
            set delete_branch 1
        else
            set branch_name "$arg"
        end
    end

    # Get the git repository root and worktree info
    set -l git_dir (git rev-parse --git-dir)
    set -l git_common_dir (git rev-parse --git-common-dir)

    # Make paths absolute
    if not string match -qr '^/' -- $git_dir
        set git_dir "$PWD/$git_dir"
    end
    if not string match -qr '^/' -- $git_common_dir
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
        # No worktree found for this branch - might have been created incorrectly
        # Try to find a worktree directory by name in tree/
        set -l tree_dir "$repo_root/tree"
        set -l potential_path "$tree_dir/$branch_name"
        set -l dir_exists (test -d "$potential_path"; echo $status)

        if test $dir_exists -eq 0
            echo "Warning: No git worktree found for branch '$branch_name', but directory exists at '$potential_path'" >&2
            set worktree_path "$potential_path"
        else
            echo "Error: No worktree found for branch '$branch_name'" >&2
            return 1
        end
    end

    # Check if working tree is clean (unless -f is passed)
    if test $force_flag -eq 0
        set -l status_output (git -C "$worktree_path" status --porcelain 2>/dev/null)

        if test -n "$status_output"
            echo "Error: Working tree for '$branch_name' has uncommitted changes" >&2
            echo "Use -f to force removal" >&2
            return 1
        end
    end

    # If we're currently in the worktree to be removed, cd to main repo first
    if test "$current_worktree_path" = "$worktree_path"
        cd "$repo_root"

        # Prompt user for confirmation when deleting branch unless -f is passed
        if test $delete_branch -eq 1 -a $force_flag -eq 0
            read -P "Remove current worktree '$branch_name' and delete branch? (y/n) " -n 1 response
            echo
            if not string match -qi "y" $response
                echo "Cancelled worktree removal."
                return 0
            end
        end
    end

    # Remove the worktree
    echo "Removing worktree for branch '$branch_name'..."

    # Try git worktree remove first
    git worktree remove "$worktree_path" 2>/dev/null
    set -l worktree_remove_status $status

    if test $worktree_remove_status -ne 0
        # If git worktree remove fails (e.g., worktree was created with incorrect branch),
        # manually remove the directory and ensure we're back at the root
        echo "Warning: git worktree remove failed, manually removing directory..." >&2

        # Ensure we're not in the directory we're trying to remove
        cd "$repo_root" 2>/dev/null
        set -l dir_exists (test -d "$worktree_path"; echo $status)

        # Remove the directory
        if test $dir_exists -eq 0
            rm -rf "$worktree_path"
            set -l rm_status $status

            if test $rm_status -eq 0
                echo "Directory removed successfully."
                # Try to prune the worktree from git's records
                git worktree prune 2>/dev/null
            else
                echo "Error: Failed to remove directory at $worktree_path" >&2
                return 1
            end
        else
            echo "Warning: Directory already removed or doesn't exist" >&2
        end
    else
        echo "Worktree removed successfully."
    end

    # Delete the branch if -d flag was passed
    if test $delete_branch -eq 1
        git show-ref --verify --quiet "refs/heads/$branch_name"
        if test $status -eq 0
            echo "Deleting branch '$branch_name'..."
            git branch -D "$branch_name" 2>/dev/null
            if test $status -eq 0
                echo "Branch deleted successfully."
            else
                echo "Warning: Failed to delete branch '$branch_name'" >&2
            end
        else
            echo "Note: Branch '$branch_name' doesn't exist or was already deleted" >&2
        end
    end
end

# Get list of worktree branches for autocomplete
function __git_tree_remove_branches
    git worktree list --porcelain 2>/dev/null \
        | string match -r "^branch refs/heads/(.+)" \
        | string replace "branch refs/heads/" ""
end

# Autocomplete for git_tree_remove - suggests worktree branches and flags
complete -c git_tree_remove -f -a '(__git_tree_remove_branches)'
complete -c git_tree_remove -s f -d 'Force removal without prompts'
complete -c git_tree_remove -s d -d 'Delete branch in addition to removing worktree'
