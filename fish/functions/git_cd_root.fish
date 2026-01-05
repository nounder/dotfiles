function git_cd_root
    set -l repo_root (project_root)
    if test $status -ne 0
        echo "Error: Not in a git repository" >&2
        return 1
    end

    cd $repo_root
end
