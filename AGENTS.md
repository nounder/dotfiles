Here you can find dotfiles for my workstation.

I use bash with `./shell.sh` config.

We use custom zig programs to enhance the shell, written in Zig such as:

- noprompt: for custom prompts,
- noenv: direnv replacement,
- nohi: for managing history,
- nozo: fast jump between directories.
- nom: auto complete, fzf alternative

Their executables and source is in ./bin, (ie. ./bin/{noprompt,.zig})

Run `zig build` after you make any changes to zig source code in this repo.

Some programs, like `nom`, have their own repo in `~/Projects`. Apply any changes
directly there and install it by doing `zig build home`, if its present, or
moving it manually to ~/bin
