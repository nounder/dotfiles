set TERM xterm-256color

set EDITOR nvim

set SHELL (which fish)

set PATH \
    "$HOME/dotfiles/bin" \
    "$HOME/.local/bin" \
    "$HOME/bin" \
    $HOME/.deno/bin \
    /usr/local/bin \
    /opt/homebrew/bin \
    /opt/homebrew/sbin \
    ~/Library/Python/3.8/bin \
    $HOME/go/bin \
    /opt/homebrew/share/google-cloud-sdk/bin \
    $PATH

set XDG_CONFIG_HOME "$HOME/.config"

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
alias s sudo
alias s3="aws s3"
alias ip=ipython

alias g="kitten hyperlinked_grep"
alias hg="kitten hyperlinked_grep"

alias tf="terraform"

alias p="less -r"

alias sc="vi ~/.config/fish/config.fish"
alias sr="source ~/.config/fish/config.fish"

alias ec="cd ~/.config/nvim/ && nvim"
alias tc="cd ~/.config/kitty/ && nvim kitty.conf"

alias gc="git checkout"
alias py="python"

alias dt="deno task"
alias dr="deno run --allow-read --allow-sys --allow-hrtime --allow-env --allow-net"
alias dw="deno run --allow-read --allow-sys --allow-hrtime --allow-env --allow-net --watch"

function fish_greeting
end

function fish_prompt
    set -g __fish_git_prompt_showupstream auto
    echo
    set_color $fish_color_cwd
    echo -n (prompt_pwd) (fish_git_prompt)
    set_color $fish_color_status
    echo -n ' λ '
    set_color normal
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

direnv hook fish | source
zoxide init fish | source
atuin init fish | source
fzf --fish | source
