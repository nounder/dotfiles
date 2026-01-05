function project_root --description "Get the root directory of the current git repository"
    # Get the common git directory (works for both regular repos and worktrees)
    set -l git_common_dir (git rev-parse --git-common-dir 2>/dev/null)
    if test $status -ne 0
        return 1
    end

    # Get the actual repo root by going up from .git directory
    dirname $git_common_dir
end
