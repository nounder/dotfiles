Default shell: bash

Config & shell profile: ./shell.sh

We use custom zig programs to enhance the shell, written in Zig such as:

- noprompt: for custom prompts,
- noenv: direnv replacement,
- nohi: for managing history,
- nozo: fast jump between directories.

Their executables and source is in ./bin, (ie. bin/{noprompt,.zig})

Run `zig build` after you make any changes to zig source code.
