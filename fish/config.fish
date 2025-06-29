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

set -x EDITOR (which nvim)

set fzf_preview_file_cmd "bat --style=plain --color=always"
set FZF_DEFAULT_OPTS '--cycle --layout=reverse --height=90% --preview-window=wrap --marker="*" --border --no-scrollbar --preview-window=border-left'

set -x SHELL (which fish)

set -x XDG_CONFIG_HOME "$HOME/.config"

set HOMEBREW_PREFIX /opt/homebrew
set HOMEBREW_CELLAR /opt/homebrew/Cellar
set HOMEBREW_REPOSITORY /opt/homebrew

alias c="pbcopy"
alias p="p"
alias shc "vi ~/.config/fish/config.fish"
alias shd "cd ~/.config/fish"
alias nr "npm run"
alias ns "npm start"
alias vi nvim
alias e nvim
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

alias doka="docker kill (docker ps -q)"
alias doc="docker compose"
alias docu="doc up"
alias docd="doc down"
alias doce="doc exec"
alias docl="doc logs"

alias dve="devcontainers exec --workspace-folder ."
alias dvu="devcontainers up --workspace-folder ."

alias g="kitten hyperlinked_grep"
alias hg="kitten hyperlinked_grep"

alias tf="terraform"

alias p="less -r"

alias sc="vi ~/.config/fish/config.fish"
alias sr="source ~/.config/fish/config.fish"

alias ec="cd ~/.config/nvim/ && nvim"
alias tc="cd ~/.config/kitty/ && nvim kitty.conf"

alias gc="git checkout"
alias gc1="git clone --depth=1"
alias py="python"

alias dt="deno task"
alias dr="deno run --allow-read --allow-sys --allow-env --allow-net"
alias dw="deno run --allow-read --allow-sys --allow-env --allow-net --watch"

function fish_greeting
end

function fish_mode_prompt
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

function fish_prompt
    if not string match --quiet --regex '.*local1$' $hostname
        set_color blue
        echo -n "[$USER@"(prompt_hostname)"] "
    end

    set_color brblack
    echo -n (prompt_pwd) (fish_git_prompt)
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
