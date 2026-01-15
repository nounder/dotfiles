# Shell configuration with fish-like prompt (bash/zsh compatible)

# Exit early for non-interactive shells
[[ $- != *i* ]] && return

# Readline settings (bash)
if [[ -n "$BASH_VERSION" ]]; then
    bind 'set show-all-if-ambiguous on'
    bind 'set bell-style none'
    bind 'set completion-ignore-case on'
    bind 'set completion-map-case on'
    # Don't save cd commands in history
    HISTIGNORE="cd:cd *:cd -:..:--"
fi

# Detect shell and arch
if [ -n "$ZSH_VERSION" ]; then
    CURRENT_SHELL="zsh"
elif [ -n "$BASH_VERSION" ]; then
    CURRENT_SHELL="bash"
fi

case "$(uname -sm)" in
    "Darwin arm64") _ARCH="darwin-arm64" ;;
    "Linux aarch64") _ARCH="linux-arm64" ;;
    "Linux x86_64") _ARCH="linux-amd64" ;;
esac

# Icons (nerd font)
ICON_FOLDER=$'\uF401 '
ICON_WORKTREE=$'\uF52E '
ICON_BRANCH=$'\uF418 '

# Check if in a git worktree
is_in_worktree() {
    local git_dir git_common_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)

    if [[ -n "$git_dir" && -n "$git_common_dir" ]]; then
        git_dir=$(realpath "$git_dir" 2>/dev/null)
        git_common_dir=$(realpath "$git_common_dir" 2>/dev/null)

        if [[ "$git_dir" != "$git_common_dir" ]]; then
            return 0
        fi
    fi
    return 1
}

# Get directory icon based on repo type
directory_icon() {
    if is_in_worktree; then
        printf '%s' "$ICON_WORKTREE"
    else
        printf '%s' "$ICON_FOLDER"
    fi
}

# Replace $HOME with ~
tilde_path() {
    echo "$1" | sed "s|^$HOME|~|"
}

# Shorten path in repo (repo name bold, rest dimmed)
shorten_path_in_repo() {
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)

    if [[ -z "$git_root" ]]; then
        # Not in a git repo, show full path with ~ for home
        tilde_path "$PWD"
        return
    fi

    # Ensure git_root is an absolute path
    [[ "$git_root" != /* ]] && git_root="$PWD/$git_root"

    local result=""

    if is_in_worktree; then
        # In worktree: show original repo path
        local git_common_dir original_repo repo_path repo_parent repo_basename rel_path
        git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
        git_common_dir=$(realpath "$git_common_dir" 2>/dev/null)
        original_repo=$(dirname "$git_common_dir")

        # Replace home directory with ~
        repo_path=$(tilde_path "$original_repo")
        repo_parent=$(dirname "$repo_path")
        repo_basename=$(basename "$repo_path")

        # Build result with ANSI codes (not prompt escapes)
        if [[ "$repo_parent" != "." ]]; then
            result="${repo_parent}/"
        fi

        # Repo basename in bold
        result="${result}\e[1m${repo_basename}\e[0m\e[90m"

        # Get relative path from worktree root
        rel_path="${PWD#$git_root/}"
        rel_path="${rel_path%/}"

        if [[ -n "$rel_path" && "$rel_path" != "$PWD" ]]; then
            result="${result}/${rel_path}"
        fi
    else
        # Not in worktree: regular logic
        local repo_path repo_parent repo_basename rel_path
        repo_path=$(tilde_path "$git_root")
        repo_parent=$(dirname "$repo_path")
        repo_basename=$(basename "$repo_path")

        if [[ "$repo_parent" != "." ]]; then
            result="${repo_parent}/"
        fi

        # Repo basename in bold
        result="${result}\e[1m${repo_basename}\e[0m\e[90m"

        # Get relative path from repo root
        rel_path="${PWD#$git_root/}"
        rel_path="${rel_path%/}"

        if [[ -n "$rel_path" && "$rel_path" != "$PWD" ]]; then
            result="${result}/${rel_path}"
        fi
    fi

    echo -e "$result"
}

# Get git icon if in repo
prompt_git_icon() {
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [[ -n "$git_dir" ]]; then
        echo -e "\e[33m$(directory_icon)\e[90m"
    fi
}

# Get git branch with icon
prompt_git_branch() {
    local git_dir branch max_branch_len cols
    git_dir=$(git rev-parse --git-dir 2>/dev/null)

    if [[ -n "$git_dir" ]]; then
        branch=$(git branch --show-current 2>/dev/null)
        if [[ -n "$branch" ]]; then
            # Calculate max branch length based on terminal width
            cols=${COLUMNS:-80}
            max_branch_len=$((cols - 13))

            # Truncate branch if too long
            if [[ $max_branch_len -gt 0 && ${#branch} -gt $max_branch_len ]]; then
                branch="${branch:0:$((max_branch_len - 3))}..."
            fi

            echo -e " \e[33m${ICON_BRANCH}${branch}\e[90m"
        fi
    fi
}

# Build the prompt
build_prompt() {
    local git_icon path_part branch_part

    git_icon=$(prompt_git_icon)
    path_part=$(shorten_path_in_repo)
    branch_part=$(prompt_git_branch)

    # Newline, then grey color, git icon, path, branch
    echo -e "\n\e[90m${git_icon}${path_part}${branch_part}\e[0m"
}

# Set up prompt based on shell
NOUNDER_PROMPT="$HOME/dotfiles/bin/noprompt-$_ARCH"

if [[ "$CURRENT_SHELL" == "zsh" ]]; then
    # Zsh prompt setup
    setopt PROMPT_SUBST
    if [[ -x "$NOUNDER_PROMPT" ]]; then
        precmd() {
            PROMPT="$("$NOUNDER_PROMPT")"
        }
    else
        precmd() {
            PROMPT="$(build_prompt)"$'\n''%B%F{red}$ %f%b'
        }
    fi
else
    # Bash prompt setup
    if [[ -x "$NOUNDER_PROMPT" ]]; then
        set_prompt() {
            PS1="$("$NOUNDER_PROMPT")"
        }
    else
        set_prompt() {
            local prompt_top
            prompt_top=$(build_prompt)
            PS1="${prompt_top}\n\[\e[1;31m\]\$ \[\e[0m\]"
        }
    fi
    PROMPT_COMMAND=set_prompt
fi

# PATH setup
export PATH="$HOME/dotfiles/bin:$HOME/.bun/bin:$HOME/.cargo/bin:$HOME/.local/bin:$HOME/bin:$HOME/.deno/bin:/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/go/bin:$PATH:node_modules/.bin:../node_modules/.bin:$HOME/.lmstudio/bin"

# Environment variables
if [[ "$CURRENT_SHELL" == "zsh" ]]; then
    export SHELL=$(which zsh)
else
    export SHELL=$(which bash)
fi
export EDITOR=$(which nvim)
export XDG_CONFIG_HOME="$HOME/.config"
export FZF_DEFAULT_OPTS='--cycle --layout=default --height=90% --preview-window=wrap --marker="*" --no-scrollbar --preview-window=border-left'
export TERM=xterm-256color

# Aliases
alias tscheck="tsgo --skipLibCheck --noEmit"
alias c="pbcopy"
alias shc="vi ~/.bashrc"
alias vi=nvim
alias e='$EDITOR'
alias f=yazi
alias y=yazi
alias g=lazygit
alias t=tmux-project
alias s=sudo
alias s3="aws s3"
alias ip=ipython
alias l="lsd --group-dirs first"
alias br="bun run"
alias brw="bun run --watch"
alias brh="bun run --hot"
alias bt="bun test"
alias btw="bun test --watch"
alias tsc="bun run tsc"
alias doka='docker kill $(docker ps -q)'
alias doc="docker compose"
alias docu="doc up"
alias docd="doc down"
alias doce="doc exec"
alias docl="doc logs"
alias tf="terraform"
alias p="less -r"
alias sc="vi ~/.bashrc"
alias sr="source ~/.bashrc"
alias ec="cd ~/.config/nvim/ && nvim"
alias tc="cd ~/.config/kitty/ && nvim kitty.conf"
alias gc="git checkout"
alias gf="git fetch"
alias gp="git pull"
alias gr="git reset"
alias gs="git switch"
alias gca="git commit --amend"
alias gc1="git clone --depth=1"
alias py="python"
alias ..="cd .."
alias -- -="cd -"
alias claude="claude --dangerously-skip-permissions"
alias sonnet="claude --model sonnet"
alias opus="claude --model opus"
alias haiku="claude --model haiku"

# noenv hook (lightweight direnv alternative)
_NOENV_BIN="$HOME/dotfiles/bin/noenv-$_ARCH"
if [[ -x "$_NOENV_BIN" ]]; then
    noenv() {
        "$_NOENV_BIN" "$@"
    }
    _noenv_hook() {
        eval "$("$_NOENV_BIN" hook)"
    }
    if [[ "$CURRENT_SHELL" == "zsh" ]]; then
        precmd_functions+=(_noenv_hook)
    else
        PROMPT_COMMAND="_noenv_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
    fi
fi

# z - jump around (using nozo)
NOZO="$HOME/dotfiles/bin/nozo-$_ARCH"
if [[ -x "$NOZO" ]]; then
    z() {
        local result=$("$NOZO" "$@")
        [[ -d "$result" ]] && cd "$result" || [[ -n "$result" ]] && echo "$result"
    }
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}($NOZO --add \"\$PWD\" &)"
fi

# FZF Functions
_fzf_search_history() {
    local selected
    selected=$(history | sed 's/^ *[0-9]* *//' | awk '!seen[$0]++' | fzf --scheme=history --prompt="History> " --query="$READLINE_LINE")
    if [[ -n "$selected" ]]; then
        READLINE_LINE="$selected"
        READLINE_POINT=${#selected}
    fi
}

_fzf_search_directory() {
    local fd_cmd selected
    if command -v fdfind &> /dev/null; then
        fd_cmd="fdfind"
    elif command -v fd &> /dev/null; then
        fd_cmd="fd"
    else
        fd_cmd="find . -type f"
    fi

    if [[ "$fd_cmd" == "find"* ]]; then
        selected=$($fd_cmd 2>/dev/null | fzf --multi --prompt="Directory> ")
    else
        selected=$($fd_cmd --color=always 2>/dev/null | fzf --ansi --multi --prompt="Directory> ")
    fi

    if [[ -n "$selected" ]]; then
        if [[ -z "$READLINE_LINE" ]]; then
            ${EDITOR:-vim} $selected
        else
            READLINE_LINE="${READLINE_LINE}${selected}"
            READLINE_POINT=${#READLINE_LINE}
        fi
    fi
}

_fzf_search_git_log() {
    if ! git rev-parse --git-dir &>/dev/null; then
        echo "Not in a git repository" >&2
        return
    fi

    local format='%C(bold blue)%h%C(reset) - %C(cyan)%ad%C(reset) %C(yellow)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)'
    local selected
    selected=$(git log --no-show-signature --color=always --format=format:"$format" --date=short | \
        fzf --ansi --multi --scheme=history --prompt="Git Log> " \
            --preview='git show --color=always --stat --patch {1}')

    if [[ -n "$selected" ]]; then
        local hashes=""
        while IFS= read -r line; do
            local abbrev=$(echo "$line" | awk '{print $1}')
            local full=$(git rev-parse "$abbrev" 2>/dev/null)
            [[ -n "$full" ]] && hashes="$hashes $full"
        done <<< "$selected"
        hashes="${hashes# }"
        READLINE_LINE="${READLINE_LINE}${hashes}"
        READLINE_POINT=${#READLINE_LINE}
    fi
}

_fzf_search_git_status() {
    if ! git rev-parse --git-dir &>/dev/null; then
        echo "Not in a git repository" >&2
        return
    fi

    local selected
    selected=$(git -c color.status=always status --short | \
        fzf --ansi --multi --prompt="Git Status> " --nth="2.." \
            --preview='file=$(echo {} | sed "s/^...//" | sed "s/.* -> //"); git diff --color=always -- "$file" 2>/dev/null || cat "$file"')

    if [[ -n "$selected" ]]; then
        local paths=""
        while IFS= read -r line; do
            local path
            if [[ "${line:0:1}" == "R" ]]; then
                path=$(echo "$line" | sed 's/.* -> //')
            else
                path=$(echo "$line" | sed 's/^...//')
            fi
            paths="$paths $path"
        done <<< "$selected"
        paths="${paths# }"
        READLINE_LINE="${READLINE_LINE}${paths}"
        READLINE_POINT=${#READLINE_LINE}
    fi
}

_fzf_tab_complete() {
    local line="${READLINE_LINE:0:$READLINE_POINT}"

    # Empty prompt - use directory search
    if [[ -z "$line" ]]; then
        _fzf_search_directory
        return
    fi

    local words=($line)
    local word="${line##* }"
    local cmd="${words[0]}"
    local completions=""
    local prompt="Complete"
    local prefix_dir=""

    if [[ ${#words[@]} -le 1 && "$line" != *" " ]]; then
        # Completing command name
        prompt="Command"
        completions=$(compgen -c -- "$word" 2>/dev/null | head -100)
    else
        # Completing arguments - try to get context-aware completions

        # Check if command has custom completion
        local compspec=$(complete -p "$cmd" 2>/dev/null)

        if [[ -n "$compspec" ]]; then
            # Extract completion function or command
            if [[ "$compspec" =~ -F[[:space:]]+([^[:space:]]+) ]]; then
                local compfunc="${BASH_REMATCH[1]}"
                prompt="$cmd"
                # Set up completion variables and call the function
                COMP_WORDS=($line)
                COMP_CWORD=$((${#words[@]} - 1))
                [[ "$line" == *" " ]] && COMP_CWORD=$((COMP_CWORD + 1))
                COMP_LINE="$READLINE_LINE"
                COMP_POINT="$READLINE_POINT"
                COMPREPLY=()
                $compfunc "$cmd" "$word" "${words[-2]:-}" 2>/dev/null
                completions=$(printf '%s\n' "${COMPREPLY[@]}")
            elif [[ "$compspec" =~ -C[[:space:]]+([^[:space:]]+) ]]; then
                local compcmd="${BASH_REMATCH[1]}"
                prompt="$cmd"
                completions=$($compcmd "$cmd" "$word" "${words[-2]:-}" 2>/dev/null)
            fi
        fi

        # Fall back to file/directory completion if no custom completions
        if [[ -z "$completions" ]]; then
            # Check if word looks like an option
            if [[ "$word" == -* ]]; then
                prompt="Option"
                # Try to get options from --help
                local help_opts=$($cmd --help 2>/dev/null | grep -oE '(^|[[:space:]])-[a-zA-Z-]+' | tr -d ' ' | sort -u | head -50)
                if [[ -n "$help_opts" ]]; then
                    completions="$help_opts"
                fi
            fi

            # Add file completions - check for directory prefix
            prompt="${prompt:-File}"
            if [[ "$word" == */* ]]; then
                local dir_part="${word%/*}"
                local file_part="${word##*/}"
                if [[ -d "$dir_part" ]]; then
                    prefix_dir="$dir_part"
                    completions=$(cd "$dir_part" && compgen -f -- "$file_part" 2>/dev/null)
                else
                    local file_completions=$(compgen -f -- "$word" 2>/dev/null)
                    [[ -n "$file_completions" ]] && completions="${completions}${completions:+$'\n'}${file_completions}"
                fi
            else
                local file_completions=$(compgen -f -- "$word" 2>/dev/null)
                [[ -n "$file_completions" ]] && completions="${completions}${completions:+$'\n'}${file_completions}"
            fi
        fi
    fi

    if [[ -n "$completions" ]]; then
        local selected fzf_key unique_completions
        unique_completions=$(echo "$completions" | awk '!seen[$0]++')
        # Auto-select if only one candidate
        if [[ $(echo "$unique_completions" | wc -l) -eq 1 ]]; then
            selected="$unique_completions"
            fzf_key="tab"
        else
            selected=$(echo "$unique_completions" | fzf --height=40% --reverse --prompt="${prompt}> " --query="${word##*/}" --expect=tab)
            fzf_key=${selected%%$'\n'*}
            selected=${selected#*$'\n'}
        fi
        if [[ -n "$selected" ]]; then
            local prefix="${READLINE_LINE:0:$((READLINE_POINT - ${#word}))}"
            local suffix="${READLINE_LINE:$READLINE_POINT}"
            if [[ -n "$prefix_dir" ]]; then
                # We have a directory prefix, reconstruct the full path
                READLINE_LINE="${prefix}${prefix_dir}/${selected}${suffix}"
                READLINE_POINT=$((${#prefix} + ${#prefix_dir} + 1 + ${#selected}))
            elif [[ "$word" == */* && "$selected" != /* ]]; then
                local word_dir="${word%/*}"
                READLINE_LINE="${prefix}${word_dir}/${selected}${suffix}"
                READLINE_POINT=$((${#prefix} + ${#word_dir} + 1 + ${#selected}))
            else
                READLINE_LINE="${prefix}${selected}${suffix}"
                READLINE_POINT=$((${#prefix} + ${#selected}))
            fi
            # If Enter was pressed (not tab), execute the command
            if [[ "$fzf_key" != "tab" ]]; then
                printf '%s\n' "$READLINE_LINE"
                eval "$READLINE_LINE"
                READLINE_LINE=""
                READLINE_POINT=0
            fi
        fi
    fi
}

# FZF Keybindings
if [[ "$CURRENT_SHELL" == "zsh" ]]; then
    _fzf_search_history_widget() {
        local selected
        selected=$(fc -l 1 | sed 's/^ *[0-9]* *//' | awk '!seen[$0]++' | fzf --scheme=history --prompt="History> " --query="$BUFFER")
        if [[ -n "$selected" ]]; then
            BUFFER="$selected"
            CURSOR=${#selected}
        fi
        zle redisplay
    }
    zle -N _fzf_search_history_widget

    _fzf_search_directory_widget() {
        local fd_cmd selected
        if command -v fdfind &> /dev/null; then
            fd_cmd="fdfind"
        elif command -v fd &> /dev/null; then
            fd_cmd="fd"
        else
            fd_cmd="find . -type f"
        fi

        if [[ "$fd_cmd" == "find"* ]]; then
            selected=$($fd_cmd 2>/dev/null | fzf --multi --prompt="Directory> ")
        else
            selected=$($fd_cmd --color=always 2>/dev/null | fzf --ansi --multi --prompt="Directory> ")
        fi

        if [[ -n "$selected" ]]; then
            if [[ -z "$BUFFER" ]]; then
                zle redisplay
                ${EDITOR:-vim} $selected
            else
                BUFFER="${BUFFER}${selected}"
                CURSOR=${#BUFFER}
            fi
        fi
        zle redisplay
    }
    zle -N _fzf_search_directory_widget

    _fzf_search_git_log_widget() {
        if ! git rev-parse --git-dir &>/dev/null; then
            zle -M "Not in a git repository"
            return
        fi

        local format='%C(bold blue)%h%C(reset) - %C(cyan)%ad%C(reset) %C(yellow)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)'
        local selected
        selected=$(git log --no-show-signature --color=always --format=format:"$format" --date=short | \
            fzf --ansi --multi --scheme=history --prompt="Git Log> " \
                --preview='git show --color=always --stat --patch {1}')

        if [[ -n "$selected" ]]; then
            local hashes=""
            while IFS= read -r line; do
                local abbrev=$(echo "$line" | awk '{print $1}')
                local full=$(git rev-parse "$abbrev" 2>/dev/null)
                [[ -n "$full" ]] && hashes="$hashes $full"
            done <<< "$selected"
            hashes="${hashes# }"
            BUFFER="${BUFFER}${hashes}"
            CURSOR=${#BUFFER}
        fi
        zle redisplay
    }
    zle -N _fzf_search_git_log_widget

    _fzf_search_git_status_widget() {
        if ! git rev-parse --git-dir &>/dev/null; then
            zle -M "Not in a git repository"
            return
        fi

        local selected
        selected=$(git -c color.status=always status --short | \
            fzf --ansi --multi --prompt="Git Status> " --nth="2.." \
                --preview='file=$(echo {} | sed "s/^...//" | sed "s/.* -> //"); git diff --color=always -- "$file" 2>/dev/null || cat "$file"')

        if [[ -n "$selected" ]]; then
            local paths=""
            while IFS= read -r line; do
                local path
                if [[ "${line:0:1}" == "R" ]]; then
                    path=$(echo "$line" | sed 's/.* -> //')
                else
                    path=$(echo "$line" | sed 's/^...//')
                fi
                paths="$paths $path"
            done <<< "$selected"
            paths="${paths# }"
            BUFFER="${BUFFER}${paths}"
            CURSOR=${#BUFFER}
        fi
        zle redisplay
    }
    zle -N _fzf_search_git_status_widget

    _fzf_complete_widget() {
        local word cmd completions prompt prefix_dir
        word="${LBUFFER##* }"
        cmd="${LBUFFER%% *}"
        prompt="Complete"
        prefix_dir=""

        if [[ "$LBUFFER" != *" "* ]]; then
            # Completing command name
            prompt="Command"
            completions=$(compgen -c -- "$word" 2>/dev/null | head -100)
        else
            # Fall back to file/option completion
            if [[ "$word" == -* ]]; then
                prompt="Option"
                # Try to get options from --help
                local help_opts=$("$cmd" --help 2>/dev/null | grep -oE '(^|[[:space:]])-[a-zA-Z-]+' | tr -d ' ' | sort -u | head -50)
                [[ -n "$help_opts" ]] && completions="$help_opts"
            fi

            # Add file completions
            prompt="${prompt:-File}"
            # Check if word has a directory prefix that exists
            if [[ "$word" == */* ]]; then
                local dir_part="${word%/*}"
                local file_part="${word##*/}"
                if [[ -d "$dir_part" ]]; then
                    prefix_dir="$dir_part"
                    # Get completions relative to the directory
                    completions=$(cd "$dir_part" && compgen -f -- "$file_part" 2>/dev/null)
                else
                    local file_completions=$(compgen -f -- "$word" 2>/dev/null)
                    [[ -n "$file_completions" ]] && completions="${completions}${completions:+$'\n'}${file_completions}"
                fi
            else
                local file_completions=$(compgen -f -- "$word" 2>/dev/null)
                [[ -n "$file_completions" ]] && completions="${completions}${completions:+$'\n'}${file_completions}"
            fi
        fi

        if [[ -n "$completions" ]]; then
            local selected fzf_key unique_completions
            unique_completions=$(echo "$completions" | awk '!seen[$0]++')
            # Auto-select if only one candidate
            if [[ $(echo "$unique_completions" | wc -l) -eq 1 ]]; then
                selected="$unique_completions"
                fzf_key="tab"
            else
                selected=$(echo "$unique_completions" | fzf --height=40% --reverse --prompt="${prompt}> " --query="${word##*/}" --expect=tab)
                fzf_key=${selected%%$'\n'*}
                selected=${selected#*$'\n'}
            fi
            if [[ -n "$selected" ]]; then
                if [[ -n "$prefix_dir" ]]; then
                    # We have a directory prefix, reconstruct the full path
                    LBUFFER="${LBUFFER%$word}${prefix_dir}/${selected}"
                elif [[ "$word" == */* && "$selected" != /* ]]; then
                    LBUFFER="${LBUFFER%/*}/$selected"
                elif [[ -n "$word" ]]; then
                    LBUFFER="${LBUFFER%$word}$selected"
                else
                    LBUFFER="${LBUFFER}$selected"
                fi
                # If Enter was pressed (not tab), execute the command
                if [[ "$fzf_key" != "tab" ]]; then
                    zle accept-line
                    return
                fi
            fi
        fi
        zle redisplay
    }
    zle -N _fzf_complete_widget

    _fzf_tab_widget() {
        if [[ -z "$LBUFFER" ]]; then
            _fzf_search_directory_widget
        else
            _fzf_complete_widget
        fi
    }
    zle -N _fzf_tab_widget

    bindkey '^R' _fzf_search_history_widget
    bindkey '\e^F' _fzf_search_directory_widget
    bindkey '\e^L' _fzf_search_git_log_widget
    bindkey '\e^S' _fzf_search_git_status_widget
    bindkey '^I' _fzf_tab_widget
else
    bind -x '"\C-r": _fzf_search_history'
    bind -x '"\e\C-f": _fzf_search_directory'
    bind -x '"\e\C-l": _fzf_search_git_log'
    bind -x '"\e\C-s": _fzf_search_git_status'
    bind -x '"\t": _fzf_tab_complete'
fi
