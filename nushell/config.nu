# config.nu

# Installed by:
# version = "0.105.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html

#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options
#
# You can remove these comments if you want or leave
# them for future reference.

$env.config.buffer_editor = "nvim"
$env.config.show_banner = false

# Git prompt helpers
def is_in_worktree [] {
    let git_dir = (do { git rev-parse --git-dir } | complete)
    let git_common_dir = (do { git rev-parse --git-common-dir } | complete)

    if $git_dir.exit_code != 0 or $git_common_dir.exit_code != 0 {
        return false
    }

    let git_dir_resolved = ($git_dir.stdout | str trim | path expand)
    let git_common_dir_resolved = ($git_common_dir.stdout | str trim | path expand)

    $git_dir_resolved != $git_common_dir_resolved
}

def directory_icon [] {
    if (is_in_worktree) { " " } else { " " }
}

def branch_icon [] {
    "\u{f418} "
}

def get_git_root [] {
    let result = (do { git rev-parse --show-toplevel } | complete)
    if $result.exit_code == 0 {
        $result.stdout | str trim
    } else {
        null
    }
}

def get_git_branch [] {
    let result = (do { git branch --show-current } | complete)
    if $result.exit_code == 0 {
        $result.stdout | str trim
    } else {
        null
    }
}

def shorten_path_in_repo [] {
    let git_root = (get_git_root)

    if $git_root == null {
        # Not in a git repo, show full path with ~ for home
        return ($env.PWD | str replace $env.HOME '~')
    }

    let repo_path = if (is_in_worktree) {
        # In worktree: get original repo path
        let git_common_dir = (do { git rev-parse --git-common-dir } | complete | get stdout | str trim | path expand)
        $git_common_dir | path dirname
    } else {
        $git_root
    }

    let repo_path_display = ($repo_path | str replace $env.HOME '~')
    let repo_parent = ($repo_path_display | path dirname)
    let repo_basename = ($repo_path_display | path basename)

    # Get relative path from git root to current directory
    let rel_path = if $env.PWD == $git_root {
        ""
    } else {
        $env.PWD | str replace $"($git_root)/" ""
    }

    # Build the path string
    let parent_part = if $repo_parent != "." { $"($repo_parent)/" } else { "" }
    let rel_part = if ($rel_path | str length) > 0 { $"/($rel_path)" } else { "" }

    $"($parent_part)(ansi attr_bold)($repo_basename)(ansi reset)(ansi dark_gray)($rel_part)"
}

def prompt_git_icon [] {
    let git_root = (get_git_root)
    if $git_root != null {
        $"(ansi yellow)(directory_icon)(ansi dark_gray)"
    } else {
        ""
    }
}

def prompt_git_branch [] {
    let branch = (get_git_branch)
    if $branch == null or ($branch | str length) == 0 {
        return ""
    }

    let max_len = ((term size).columns - 13)
    let truncated = if ($branch | str length) > $max_len {
        $"(($branch | str substring 0..($max_len - 3)))..."
    } else {
        $branch
    }

    $" (ansi yellow)(branch_icon)($truncated)(ansi dark_gray)"
}

# Main prompt
$env.PROMPT_COMMAND = {||
    let git_icon = (prompt_git_icon)
    let path = (shorten_path_in_repo)
    let branch = (prompt_git_branch)

    $"\n(ansi dark_gray)($git_icon)($path)($branch)(ansi reset)\n"
}
$env.PROMPT_COMMAND_RIGHT = ""
$env.PROMPT_INDICATOR = {|| $"(ansi red_bold)$ (ansi reset)" }

$env.config.keybindings = ($env.config.keybindings | append [
    {
        name: file_picker
        modifier: control
        keycode: char_t
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: executehostcommand
            cmd: "commandline edit --insert (fd --type f | lines | input list --fuzzy 'File: ')"
        }
    }
    {
        name: history_picker
        modifier: control
        keycode: char_r
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: executehostcommand
            cmd: "commandline edit --replace (history | get command | uniq | reverse | where {|cmd| not ($cmd | str starts-with ' ') and not ($cmd | str starts-with '#') and not ($cmd | str contains (char nl))} | input list --fuzzy 'History: ')"
        }
    }
])

# direnv-like .env auto-loading with stacking
$env._dotenv_stack = []

def _load_dotenv [path: string] {
    let dotenv_path = ($path | path join ".env")
    if ($dotenv_path | path exists) {
        let vars = (open $dotenv_path
            | lines
            | where {|line| not ($line | str starts-with '#') and ($line | str contains '=')}
            | each {|line|
                let parts = ($line | split column '=' key value)
                {name: ($parts.key.0 | str trim), value: ($parts.value.0? | default '' | str trim | str trim -c '"' | str trim -c "'")}
            }
        )
        if ($vars | length) > 0 {
            for var in $vars {
                load-env {($var.name): $var.value}
            }
            let vars_str = ($vars | get name | each {|v| $"(ansi green)+($v)(ansi reset)"} | str join ' ')
            print $"(ansi green_bold).env:(ansi reset) ($vars_str)"
            {path: $path, vars: ($vars | get name)}
        } else {
            null
        }
    } else {
        null
    }
}

$env.config.hooks.env_change = ($env.config.hooks.env_change | default {} | merge {
    PWD: [{|before, after|
        # Unload envs from directories we've left
        let to_unload = ($env._dotenv_stack | where {|entry| not ($after | str starts-with $entry.path)})
        let to_keep = ($env._dotenv_stack | where {|entry| $after | str starts-with $entry.path})

        for entry in $to_unload {
            for var in $entry.vars {
                hide-env -i $var
            }
            let vars_str = ($entry.vars | each {|v| $"(ansi red)-($v)(ansi reset)"} | str join ' ')
            print $"(ansi yellow_bold).env:(ansi reset) ($vars_str)"
        }
        $env._dotenv_stack = $to_keep

        # Find new directories to check for .env files
        let loaded_paths = ($env._dotenv_stack | get path? | default [])
        let path_parts = ($after | path split)
        mut current = ""
        for part in $path_parts {
            $current = ([$current, $part] | path join)
            if ($current not-in $loaded_paths) {
                let result = (_load_dotenv $current)
                if ($result != null) {
                    $env._dotenv_stack = ($env._dotenv_stack | append $result)
                }
            }
        }
    }]
})

# Aliases
alias tscheck = tsgo --skipLibCheck --noEmit
alias c = pbcopy
alias vi = nvim
alias e = nvim
alias s = sudo
alias s3 = aws s3
alias ip = ipython
alias l = ls -a
alias p = less -r

# Bun
alias br = bun run
alias brw = bun run --watch
alias brh = bun run --hot
alias bt = bun test
alias btw = bun test --watch
alias tsc = bun run tsc

# Docker
alias doc = docker compose
alias docu = docker compose up
alias docd = docker compose down
alias doce = docker compose exec
alias docl = docker compose logs
def doka [] { docker ps -q | lines | each { |id| docker kill $id } }

# Terraform
alias tf = terraform

# Shell config
alias sc = nvim ~/.config/nushell/config.nu

# Editor config
def ec [] { cd ~/.config/nvim; nvim }
def tc [] { cd ~/.config/kitty; nvim kitty.conf }

# Git
alias gc = git checkout
alias gf = git fetch
alias gp = git pull
alias gr = git reset
alias gs = git switch
alias gta = git worktree add
alias gca = git commit --amend
alias gc1 = git clone --depth=1
def gd [] { cd (git rev-parse --show-toplevel) }
def gg [] { nvim -c 'lua require("neogit").open()' }

# Python
alias py = python

# Claude
alias claude = claude --dangerously-skip-permissions
alias sonnet = claude --model sonnet
alias opus = claude --model opus
alias haiku = claude --model haiku

# AI command using Anthropic API
def ai [
    prompt: string        # The prompt to send
    --model (-m): string  # Model to use (default: claude-sonnet-4-20250514)
    --system (-s): string # System prompt
] {
    let api_key = ($env.ANTHROPIC_API_KEY? | default "")
    if $api_key == "" {
        error make {msg: "ANTHROPIC_API_KEY environment variable not set"}
    }

    let model_name = ($model | default "claude-sonnet-4-20250514")
    let messages = [{role: "user", content: $prompt}]
    let body = if $system != null {
        {model: $model_name, max_tokens: 4096, system: $system, messages: $messages}
    } else {
        {model: $model_name, max_tokens: 4096, messages: $messages}
    }

    let response = (http post
        --content-type "application/json"
        --headers ["x-api-key" $api_key "anthropic-version" "2023-06-01"]
        "https://api.anthropic.com/v1/messages"
        $body
    )

    $response.content.0.text
}

