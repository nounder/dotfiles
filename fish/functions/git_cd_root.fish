function git_cd_root
    # Get the common git directory (works for both regular repos and worktrees)
    set git_common_dir (git rev-parse --git-common-dir 2>/dev/null)
    if test $status -ne 0
        echo "Error: Not in a git repository" >&2
        return 1
    end

    # Get the actual repo root by going up from .git directory
    set repo_root (dirname $git_common_dir)
    cd $repo_root
end
