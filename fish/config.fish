set TERM xterm-256color

set PATH \
    "$HOME/dotfiles/bin" \
    "$HOME/.bun/bin" \
    "$HOME/.cargo/bin" \
    "$HOME/.local/bin" \
    "$HOME/bin" \
    $HOME/.deno/bin \
    /usr/local/bin \
    /opt/homebrew/bin \
    /opt/homebrew/sbin \
    $HOME/go/bin \
    $PATH \
    $HOME/.bun/bin \
    node_modules/.bin \
    "../node_modules/.bin"

set BUN_AGENT_RULE_DISABLED 1
set CLAUDE_CODE_AGENT_RULE_DISABLED 1

set -x SHELL (which fish)

if not set -q EDITOR
    set -x EDITOR (which nvim)
end

set fzf_preview_file_cmd "bat --style=plain --color=always"
set FZF_DEFAULT_OPTS '--cycle --layout=reverse --height=90% --preview-window=wrap --marker="*" --border --no-scrollbar --preview-window=border-left'

set -x XDG_CONFIG_HOME "$HOME/.config"

set HOMEBREW_PREFIX /opt/homebrew
set HOMEBREW_CELLAR /opt/homebrew/Cellar
set HOMEBREW_REPOSITORY /opt/homebrew

alias c="pbcopy"
alias p="p"
alias shc "vi ~/.config/fish/config.fish"
alias shd "cd ~/.config/fish"
alias vi nvim
alias e "$EDITOR"
alias e-js "nvim -c 'set filetype=typescript' -c 'set nomodified' -"
alias p-js "dprint fmt --stdin main.ts"
alias s sudo
alias s3="aws s3"
alias ip=ipython

alias l="ls -a"

alias br="bun run"
alias brw="bun run --watch"
alias brh="bun run --hot"
alias bt="bun test"
alias btw="bun test --watch"
alias tsc="bun run tsc"

alias doka="docker kill (docker ps -q)"
alias doc="docker compose"
alias docu="doc up"
alias docd="doc down"
alias doce="doc exec"
alias docl="doc logs"

alias tf="terraform"

alias p="less -r"

alias sc="vi ~/.config/fish/config.fish"
alias sr="source ~/.config/fish/config.fish"

alias ec="cd ~/.config/nvim/ && nvim"
alias tc="cd ~/.config/kitty/ && nvim kitty.conf"

alias gc="git checkout"
alias gd="git_cd_root"
alias gf="git fetch"
alias gg="nvim -c 'lua require(\"neogit\").open()'"
alias gp="git pull"
alias gr="git reset"
alias gs="git switch"
alias gt="git_tree_enter"
alias gta="git worktree add"
alias gtr="git_tree_remove"
alias gca="git commit --amend"

alias gc1="git clone --depth=1"
alias py="python"

alias claude="claude --dangerously-skip-permissions"

function fish_greeting
end

function fish_mode_prompt
end

function shorten_path_in_repo
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)

    if test -z "$git_root"
        # Not in a git repo, show full path with ~ for home
        string replace -r "^$HOME" "~" "$PWD"
        return
    end

    # Ensure git_root is an absolute path
    if not string match -qr '^/' -- $git_root
        set git_root "$PWD/$git_root"
    end

    # Check if we're in a worktree
    if is_in_worktree
        # In worktree: show original repo path + relative path in worktree
        set -l git_common_dir (git rev-parse --git-common-dir 2>/dev/null)

        # Use realpath to resolve relative paths like "../../.git" to absolute
        set git_common_dir (realpath "$git_common_dir")

        set -l original_repo (dirname $git_common_dir)

        # Replace home directory with ~
        set -l repo_path (string replace -r "^$HOME" "~" $original_repo)

        # Get parent path and basename
        set -l repo_parent (dirname $repo_path)
        set -l repo_basename (basename $repo_path)

        # Print parent path (full, not shortened)
        if test "$repo_parent" != "."
            echo -n "$repo_parent/"
        end

        # Print repo basename in bold
        set_color --bold
        echo -n $repo_basename
        set_color normal
        set_color brblack

        # Get relative path from worktree root to current directory
        set -l rel_path (string replace "$git_root/" "" "$PWD/")
        set -l rel_path (string trim -r -c / "$rel_path")

        if test -n "$rel_path" -a "$rel_path" != "$PWD/"
            echo -n "/$rel_path"
        end
    else
        # Not in worktree: use regular logic
        # Replace home directory with ~
        set -l repo_path (string replace -r "^$HOME" "~" $git_root)

        # Get parent path and basename
        set -l repo_parent (dirname $repo_path)
        set -l repo_basename (basename $repo_path)

        # Print parent path (full, not shortened)
        if test "$repo_parent" != "."
            echo -n "$repo_parent/"
        end

        # Print repo basename in bold
        set_color --bold
        echo -n $repo_basename
        set_color normal
        set_color brblack

        # Get relative path from repo root to current directory
        set -l rel_path (string replace "$git_root/" "" "$PWD/")
        set -l rel_path (string trim -r -c / "$rel_path")

        if test -n "$rel_path" -a "$rel_path" != "$PWD/"
            echo -n "/$rel_path"
        end
    end
end

function fish_mode_indicator
    switch $fish_bind_mode
        case default
            set_color --bold red
            echo N
        case insert
            set_color --bold green
            echo I
        case replace_one
            set_color --bold green
            echo R
        case visual
            set_color --bold brmagenta
            echo V
        case '*'
            set_color --bold red
            echo '?'
    end
    set_color normal
end

function is_in_worktree
    # Returns 0 if in a git worktree, 1 otherwise
    set -l git_dir (git rev-parse --git-dir 2>/dev/null)
    set -l git_common_dir (git rev-parse --git-common-dir 2>/dev/null)

    if test -n "$git_dir" -a -n "$git_common_dir"
        # Use realpath to resolve relative paths and normalize
        set git_dir (realpath "$git_dir")
        set git_common_dir (realpath "$git_common_dir")

        # Check if we're in a worktree
        if test "$git_dir" != "$git_common_dir"
            return 0 # true
        end
    end
    return 1 # false
end

function directory_icon
    # Shows icon based on repo type (worktree vs regular)
    if is_in_worktree
        printf ' '
    else
        printf ' '
    end
end

function branch_icon
    # Shows branch icon (always the same)
    printf '\uf418 '
end

function prompt_git_icon
    # Prints git repo icon if in a git repository
    set -l git_dir (git rev-parse --git-dir 2>/dev/null)
    if test -n "$git_dir"
        set_color yellow
        directory_icon
        set_color brblack
    end
end

function prompt_git_branch
    # Prints git branch with icon, truncated if terminal is too narrow
    set -l git_dir (git rev-parse --git-dir 2>/dev/null)

    if test -n "$git_dir"
        set -l branch (git branch --show-current 2>/dev/null)
        if test -n "$branch"
            # Calculate max branch length based on terminal width
            # Reserve space for: icon (2) + space (1) + some buffer (10)
            set -l max_branch_len (math "$COLUMNS - 13")

            # Truncate branch if it's too long
            if test (string length "$branch") -gt $max_branch_len
                set branch (string sub -l (math "$max_branch_len - 3") "$branch")"..."
            end

            echo -n " "
            set_color yellow
            branch_icon
            echo -n "$branch"
            set_color brblack
        end
    end
end

function fish_prompt
    echo
    set_color brblack

    # Show git icon
    prompt_git_icon

    # Show path
    echo -n (shorten_path_in_repo)

    # Show branch
    prompt_git_branch

    # Show prompt symbol
    set_color $fish_color_status
    set_color normal
    echo
    set_color --bold red
    echo -n '$ '
    set_color normal
end

function _change_cursor --on-variable fish_bind_mode
    switch $fish_bind_mode
        case default
            # Block cursor for normal mode
            echo -ne '\e[1 q'
        case insert
            # Line cursor for insert mode
            echo -ne '\e[5 q'
        case visual
            # Optional: Beam cursor for visual mode
            echo -ne '\e[3 q'
        case replace_one
            # Optional: Underline cursor for replace mode
            echo -ne '\e[3 q'
    end
end

function add_to_z --on-event fish_postexec
    z --add "$PWD" &
end

function add_newline --on-event fish_postexec
    echo
end

function get_theme_mode
    set theme (cat ~/.config/theme-mode | string trim)

    if string match -q "*light*" $theme
        echo light
    else
        echo dark
    end
end

function check_macos_dark_mode
    set interface_style (defaults read -g AppleInterfaceStyle 2>/dev/null)
    if test "$interface_style" = Dark
        return 0 # true
    end
    return 1 # false
end

function set_theme_mode -a new_mode --on-event fish_start --on-signal USR1
    if test -z "$new_mode"
        if check_macos_dark_mode
            set new_mode dark
        else
            set new_mode light
        end
    end

    echo $new_mode >~/.config/theme-mode

    echo $new_mode

    set -U AICHAT_LIGHT_THEME true

    set theme (get_theme_mode)

    set -U -x THEME_MODE $theme

    emit theme_change $theme
end

function set_kitty_theme -a new_mode --on-event theme_change
    cd ~/.config/kitty

    if string match -q "*light*" $new_mode
        ln -sf light-theme.conf current-theme.conf
    else
        ln -sf dark-theme.conf current-theme.conf
    end

    cd -

    kitty @ load-config

    echo chaning kitty
end

type -q direnv && direnv hook fish | source

fzf_configure_bindings

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/rg/.lmstudio/bin
# End of LM Studio CLI section
