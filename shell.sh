# Shell configuration with fish-like prompt (bash/zsh compatible)

# Exit early for non-interactive shells
[[ $- != *i* ]] && return

# Disable control character display (^C, ^D, etc.)
stty -echoctl 2>/dev/null

# Reset sequence for cleaning up after abruptly terminated programs
# \e[0m    - reset text attributes (color, bold, underline, etc.)
# \e[?25h  - show cursor (in case it was hidden)
# \e[?7h   - re-enable line wrapping
# \e[?1000l\e[?1002l\e[?1003l\e[?1006l - disable all mouse tracking modes
_TERM_RESET=$'\e[0m\e[?25h\e[?7h\e[?1000l\e[?1002l\e[?1003l\e[?1006l'

# Readline settings (bash)
if [[ -n "$BASH_VERSION" ]]; then
  bind 'set show-all-if-ambiguous on'
  bind 'set bell-style none'
  bind 'set completion-ignore-case on'
  bind 'set completion-map-case on'
  bind 'set enable-bracketed-paste off'
  # Don't save cd commands in history
  HISTIGNORE="cd:cd *:cd -:..:--"

fi

# Detect shell and arch
CURRENT_SHELL="bash"

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

# Wrap ANSI escape codes for proper prompt length calculation
# Bash needs \001...\002
_esc() {
  printf '\001%s\002' "$1"
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

  local result="" bold reset dim
  bold=$(_esc $'\e[1m')
  reset=$(_esc $'\e[0m')
  dim=$(_esc $'\e[90m')

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

    if [[ "$repo_parent" != "." ]]; then
      result="${repo_parent}/"
    fi

    # Repo basename in bold
    result="${result}${bold}${repo_basename}${reset}${dim}"

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
    result="${result}${bold}${repo_basename}${reset}${dim}"

    # Get relative path from repo root
    rel_path="${PWD#$git_root/}"
    rel_path="${rel_path%/}"

    if [[ -n "$rel_path" && "$rel_path" != "$PWD" ]]; then
      result="${result}/${rel_path}"
    fi
  fi

  printf '%s' "$result"
}

# Get git icon if in repo
prompt_git_icon() {
  local git_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null)
  if [[ -n "$git_dir" ]]; then
    printf '%s%s%s' "$(_esc $'\e[33m')" "$(directory_icon)" "$(_esc $'\e[90m')"
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

      printf ' %s%s%s%s' "$(_esc $'\e[33m')" "${ICON_BRANCH}${branch}" "$(_esc $'\e[90m')"
    fi
  fi
}

# Build the prompt
build_prompt() {
  local git_icon path_part branch_part dim reset

  git_icon=$(prompt_git_icon)
  path_part=$(shorten_path_in_repo)
  branch_part=$(prompt_git_branch)
  dim=$(_esc $'\e[90m')
  reset=$(_esc $'\e[0m')

  # Newline, then grey color, git icon, path, branch
  printf '\n%s%s%s%s%s' "$dim" "$git_icon" "$path_part" "$branch_part" "$reset"
}

# Set up prompt
NOUNDER_PROMPT="$HOME/dotfiles/bin/noprompt-$_ARCH"

if [[ -x "$NOUNDER_PROMPT" ]]; then
  set_prompt() {
    PS1="\[${_TERM_RESET}\]$("$NOUNDER_PROMPT")"
  }
else
  PS1='\[\e[0m\]\n\[\e[90m\]\w\[\e[0m\]\n\[\e[1;31m\]\$ \[\e[0m\]'
fi
PROMPT_COMMAND=set_prompt

# PATH setup
export PATH="$HOME/dotfiles/bin:$HOME/.bun/bin:$HOME/.cargo/bin:$HOME/.local/bin:$HOME/bin:$HOME/.deno/bin:/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/go/bin:$PATH:node_modules/.bin:../node_modules/.bin:$HOME/.lmstudio/bin"

# Per-directory history using nohi
if [[ -n "$BASH_VERSION" ]] && command -v nohi &>/dev/null && command -v tac &>/dev/null; then
  unset HISTFILE
  _NOHI_DIR="$PWD"
  _NOHI_EXIT=0
  # Capture exit code immediately (must be first in PROMPT_COMMAND)
  _nohi_capture() { _NOHI_EXIT=$?; }
  _nohi_sync() {
    local cmd
    cmd=$(fc -ln -1 2>/dev/null)
    cmd="${cmd#"${cmd%%[![:space:]]*}"}" # trim leading whitespace
    # Skip failed commands and commands starting with space
    [[ $_NOHI_EXIT -eq 0 && -n "$cmd" && "${cmd:0:1}" != " " ]] && nohi --add "$_NOHI_DIR" "$cmd" 2>/dev/null
    # Reload history on directory change
    if [[ "$PWD" != "$_NOHI_DIR" ]]; then
      _NOHI_DIR="$PWD"
      history -c
      while IFS= read -r c; do history -s "$c"; done < <(nohi --get --recent "$PWD" 2>/dev/null | tac 2>/dev/null)
    fi
  }
  PROMPT_COMMAND="_nohi_capture;_nohi_sync${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
  while IFS= read -r cmd; do history -s "$cmd"; done < <(nohi --get --recent "$PWD" 2>/dev/null | tac 2>/dev/null)
fi

# Environment variables
export SHELL=$(which bash)
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
  PROMPT_COMMAND="_noenv_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# z - jump around (using nozo)
NOZO="$HOME/dotfiles/bin/nozo-$_ARCH"
if [[ -x "$NOZO" ]]; then
  z() {
    local result=$("$NOZO" "$@")
    if [[ -d "$result" ]]; then
      cd "$result"
    elif [[ -n "$result" ]]; then
      echo "$result"
    else
      return 1
    fi
  }
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}($NOZO --add \"\$PWD\" &)"
fi

# FZF Functions
_fzf_search_history() {
  local selected
  # Use nohi with frecency ordering if available, otherwise fall back to bash history
  if command -v nohi &>/dev/null; then
    selected=$(nohi --get "$PWD" 2>/dev/null | fzf --scheme=history --prompt="History> " --query="$READLINE_LINE")
  else
    selected=$(history | sed 's/^ *[0-9]* *//' | awk '!seen[$0]++' | fzf --scheme=history --prompt="History> " --query="$READLINE_LINE")
  fi
  if [[ -n "$selected" ]]; then
    READLINE_LINE="$selected"
    READLINE_POINT=${#selected}
  fi
}

_fzf_search_directory() {
  local fd_cmd selected
  if command -v fdfind &>/dev/null; then
    fd_cmd="fdfind"
  elif command -v fd &>/dev/null; then
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
  selected=$(git log --no-show-signature --color=always --format=format:"$format" --date=short |
    fzf --ansi --multi --scheme=history --prompt="Git Log> " \
      --preview='git show --color=always --stat --patch {1}')

  if [[ -n "$selected" ]]; then
    local hashes=""
    while IFS= read -r line; do
      local abbrev=$(echo "$line" | awk '{print $1}')
      local full=$(git rev-parse "$abbrev" 2>/dev/null)
      [[ -n "$full" ]] && hashes="$hashes $full"
    done <<<"$selected"
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
  selected=$(git -c color.status=always status --short |
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
    done <<<"$selected"
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

      # Add file completions
      prompt="${prompt:-File}"

      # Try fuzzy path completion if word contains /
      if [[ "$word" == */* ]]; then
        local glob_word="$word"
        local prefix=""

        # Handle ~ prefix: expand but preserve as literal prefix
        if [[ "$word" == "~/"* ]]; then
          prefix="$HOME/"
          glob_word="${word:2}"
        elif [[ "$word" == /* ]]; then
          prefix="/"
          glob_word="${word:1}"
        fi

        # Build glob pattern: each segment gets * appended
        # Insert * before non-alphanumeric chars (fish-style: eff-st -> eff*-st*, foo_bar -> foo*_bar*)
        local glob_pattern="" segment
        while IFS= read -r -d '/' segment; do
          if [[ -n "$segment" ]]; then
            local expanded_segment=""
            local i char
            for ((i=0; i<${#segment}; i++)); do
              char="${segment:i:1}"
              if [[ "$char" =~ [^a-zA-Z0-9] ]]; then
                expanded_segment+="*$char"
              else
                expanded_segment+="$char"
              fi
            done
            glob_pattern+="${expanded_segment}*/"
          fi
        done <<< "$glob_word/"

        # Remove extra trailing /
        glob_pattern="${glob_pattern%/}"

        # Handle trailing slash in original input
        [[ "$word" == */ ]] && glob_pattern+="/"

        local fuzzy_matches
        fuzzy_matches=$(compgen -G "${prefix}${glob_pattern}" 2>/dev/null)
        [[ -n "$fuzzy_matches" ]] && completions="${completions}${completions:+$'\n'}${fuzzy_matches}"
      fi

      # Fall back to exact compgen -f if no fuzzy matches
      if [[ -z "$completions" ]]; then
        local file_completions=$(compgen -f -- "$word" 2>/dev/null)
        [[ -n "$file_completions" ]] && completions="${completions}${completions:+$'\n'}${file_completions}"
      fi
    fi
  fi

  if [[ -n "$completions" ]]; then
    local selected fzf_key unique_completions fzf_query
    unique_completions=$(echo "$completions" | awk '!seen[$0]++')
    # For fuzzy path matches, don't pre-filter; otherwise use last segment
    if [[ "$word" == */* ]]; then
      fzf_query=""
    else
      fzf_query="${word##*/}"
    fi
    # Auto-select if only one candidate
    if [[ $(echo "$unique_completions" | wc -l) -eq 1 ]]; then
      selected="$unique_completions"
      fzf_key="tab"
    else
      selected=$(echo "$unique_completions" | fzf --height=40% --reverse --prompt="${prompt}> " --query="$fzf_query" --expect=tab)
      fzf_key=${selected%%$'\n'*}
      selected=${selected#*$'\n'}
    fi
    if [[ -n "$selected" ]]; then
      local prefix="${READLINE_LINE:0:$((READLINE_POINT - ${#word}))}"
      local suffix="${READLINE_LINE:$READLINE_POINT}"
      # compgen returns full paths, so just use selected directly
      READLINE_LINE="${prefix}${selected}${suffix}"
      READLINE_POINT=$((${#prefix} + ${#selected}))
      # If Enter was pressed (not tab), execute the command
      if [[ "$fzf_key" != "tab" ]]; then
        # Simulate pressing Enter by binding accept-line
        bind '"\e[0n": accept-line'
        printf '\e[5n'
      fi
    fi
  fi
}

# FZF Keybindings
bind -x '"\C-r": _fzf_search_history'
bind -x '"\e\C-f": _fzf_search_directory'
bind -x '"\e\C-l": _fzf_search_git_log'
bind -x '"\e\C-s": _fzf_search_git_status'
bind -x '"\t": _fzf_tab_complete'
