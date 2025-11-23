function git_tree_purge
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository" >&2
        return 1
    end

    # Parse flags
    set -l dry_run 0
    for arg in $argv
        if test "$arg" = "--dry-run" -o "$arg" = "-n"
            set dry_run 1
        end
    end

    # Get list of all worktrees with their paths
    set -l worktree_data (git worktree list --porcelain)

    if test -z "$worktree_data"
        echo "No worktrees found"
        return 0
    end

    # Parse worktree list and check each one
    set -l current_worktree ""
    set -l removed_count 0
    set -l checked_count 0

    for line in $worktree_data
        # Extract worktree path
        if string match -qr "^worktree " -- $line
            set current_worktree (string replace "worktree " "" -- $line)
            set checked_count (math $checked_count + 1)

            # Check if the directory exists
            if not test -d "$current_worktree"
                set removed_count (math $removed_count + 1)

                if test $dry_run -eq 1
                    echo "[DRY RUN] Would remove missing worktree: $current_worktree"
                else
                    echo "Removing missing worktree: $current_worktree"
                    # Remove the worktree from git's records
                    # Since the directory is already gone, we need to use prune or force remove
                    git worktree remove --force "$current_worktree" 2>/dev/null
                    if test $status -ne 0
                        echo "Warning: Failed to remove worktree record for $current_worktree" >&2
                    end
                end
            end
        end
    end

    # Run prune to clean up any remaining stale references
    if test $dry_run -eq 0
        git worktree prune 2>/dev/null
    end

    # Summary
    if test $removed_count -eq 0
        echo "No missing worktrees found"
    else
        echo ""
        echo "Checked $checked_count worktree(s)"
        if test $dry_run -eq 1
            echo "Would remove $removed_count missing worktree(s)"
            echo "Run without --dry-run to actually remove them"
        else
            echo "Removed $removed_count missing worktree(s)"
        end
    end
end

# Autocomplete for git_tree_purge - show available flags
complete -c git_tree_purge -l dry-run -s n -d 'Show what would be removed without actually removing'
