function dv --description "Open Diffview in neovim"
    nvim -c ":DiffviewOpen $argv[1]"
end
