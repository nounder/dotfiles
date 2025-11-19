function dv --description "Open Diffview in neovim"
    set -l branch $argv[1]

    # If no argument provided, detect default branch
    if test -z "$branch"
        set branch (git_default_branch)
        or return 1
    end

    nvim -c ":DiffviewOpen $branch"
end
