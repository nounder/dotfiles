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

$env.config.buffer_editor = "hx"
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

# Get the root of the current git worktree
def git-root [] {
    let result = (do { git rev-parse --show-toplevel } | complete)
    if $result.exit_code == 0 {
        $result.stdout | str trim
    } else {
        null
    }
}

# Get the root of the main project (works with worktrees)
def project-root [] {
    let result = (do { git rev-parse --git-common-dir } | complete)
    if $result.exit_code == 0 {
        $result.stdout | str trim | path expand | path dirname
    } else {
        null
    }
}

# cd to project root (main repo, not worktree)
def git-cd-root [] {
    let root = (project-root)
    if $root == null {
        error make {msg: "Not in a git repository"}
    }
    cd $root
}

# Alias for backward compatibility
def get_git_root [] {
    git-root
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
    let git_root = (git-root)

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
    let git_root = (git-root)
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

# History picker - select from command history
def history-picker [] {
    let commands = (
        history
        | get command
        | uniq
        | reverse
        | where {|cmd|
            not ($cmd | str starts-with ' ') and not ($cmd | str starts-with '#') and not ($cmd | str contains (char nl))
        }
    )

    let has_fzf = (which fzf | is-not-empty)
    let selected = if $has_fzf {
        let result = ($commands | str join "\n" | fzf --no-height --prompt "History> " --tiebreak=index)
        if ($env.LAST_EXIT_CODE != 0) { "" } else { $result | str trim }
    } else {
        try { $commands | input list --fuzzy "History: " } catch { "" }
    }

    if ($selected | is-not-empty) {
        commandline edit --replace $selected
    }
}

# File picker with frecency - opens in editor if command line is empty
def file-picker [] {
    let cmdline = (commandline)

    # Combine frecency history with fd results, deduplicated
    let files = (
        (recentf-get-cwd | wrap path)
        | append (fd --type f | lines | wrap path)
        | uniq-by path
        | get path
    )

    # Use fzf if available, fallback to input list
    let has_fzf = (which fzf | is-not-empty)
    let selected = if $has_fzf {
        let result = ($files | str join "\n" | fzf --no-height --multi --ansi --prompt "File> " --preview "bat --style=plain --color=always {}" --tiebreak=index)
        if ($env.LAST_EXIT_CODE != 0) { "" } else { $result | str trim }
    } else {
        try { $files | input list --fuzzy "File: " } catch { "" }
    }

    if ($selected | is-empty) {
        return
    }

    # Handle multi-select from fzf (newline separated)
    let selected_files = if $has_fzf {
        $selected | lines
    } else {
        [$selected]
    }

    # Add to history
    recentf-add ...$selected_files

    # If command line was empty, open in editor
    if ($cmdline | is-empty) {
        run-external $env.EDITOR ...$selected_files
    } else {
        commandline edit --insert ($selected_files | str join " ")
    }
}

# Zellij file finder - opens fzf in floating pane, inserts result
def zellij-find-file [] {
    zellij-picker insert
}

$env.config.keybindings = ($env.config.keybindings | append [
    {
        name: file-picker
        modifier: none
        keycode: tab
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: executehostcommand
            cmd: "if (commandline | is-empty) { file-picker }"
        }
    }
    {
        name: completion
        modifier: control
        keycode: char_l
        mode: [emacs, vi_insert, vi_normal]
        event: { send: Menu, name: completion_menu }
    }
    {
        name: history-picker
        modifier: control
        keycode: char_r
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: executehostcommand
            cmd: "history-picker"
        }
    }
    {
        name: zellij-find-file
        modifier: control
        keycode: char_o
        mode: [emacs, vi_insert, vi_normal]
        event: {
            send: executehostcommand
            cmd: "zellij-find-file"
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
alias e = hx
alias f = yazi
alias g = lazygit
alias t = zellij
alias s = sudo
alias s3 = aws s3
alias ip = ipython
alias l = lsd --group-dirs first
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
alias sc = hx ~/.config/nushell/config.nu

# Editor config
def ec [] { cd ~/.config/helix; hx config.toml }
def tc [] { cd ~/.config/kitty; hx kitty.conf }

# Git
alias gc = git checkout
alias gf = git fetch
alias gp = git pull
alias gr = git reset
alias gs = git switch
alias gta = git worktree add
alias gca = git commit --amend
alias gc1 = git clone --depth=1
def gd [] { git-cd-root }
def gg [] { nvim -c 'lua require("neogit").open()' }

# Python
alias py = python

# Claude
alias claude = claude --dangerously-skip-permissions
alias sonnet = claude --model sonnet
alias opus = claude --model opus
alias haiku = claude --model haiku

# =============================================================================
# Recent files (frecency-based file history)
# =============================================================================

const RECENTF_FILE = "~/.local/share/fzf_file_history"
const RECENTF_HOURLY_HALF = 3600
const RECENTF_DAILY_HALF = 86400
const RECENTF_MONTHLY_HALF = 2592000
const RECENTF_HOURLY_WEIGHT = 720
const RECENTF_DAILY_WEIGHT = 30
const RECENTF_MONTHLY_WEIGHT = 1

# Add files to recent files history
def recentf-add [
    ...files: string  # Files to add to history
] {
    let history_file = ($RECENTF_FILE | path expand)
    let now = (date now | into int) // 1_000_000_000

    mkdir ($history_file | path dirname)
    touch $history_file

    # Load existing entries
    mut entries = (
        open $history_file
        | lines
        | where { $in | str length | $in > 0 }
        | each { |line|
            let parts = ($line | split column ":" path hourly daily monthly ts)
            if ($parts | length) > 0 {
                {
                    path: $parts.path.0,
                    hourly: ($parts.hourly.0 | into float),
                    daily: ($parts.daily.0 | into float),
                    monthly: ($parts.monthly.0 | into float),
                    ts: ($parts.ts.0 | into int)
                }
            } else {
                null
            }
        }
        | where { $in != null }
    )

    # Process each file
    for f in $files {
        let abs_path = try {
            let resolved = ($f | path expand)
            if ($resolved | path type) == "dir" {
                $"($resolved)/"
            } else {
                $resolved
            }
        } catch {
            continue
        }

        # Find existing entry
        let idx = ($entries | enumerate | where { $in.item.path == $abs_path } | get index? | first | default (-1))

        if $idx >= 0 {
            # Update existing entry with decay
            let entry = ($entries | get $idx)
            let elapsed = $now - $entry.ts
            let new_hourly = (($entry.hourly * (2 ** (-1 * $elapsed / $RECENTF_HOURLY_HALF))) + 1)
            let new_daily = (($entry.daily * (2 ** (-1 * $elapsed / $RECENTF_DAILY_HALF))) + 1)
            let new_monthly = (($entry.monthly * (2 ** (-1 * $elapsed / $RECENTF_MONTHLY_HALF))) + 1)
            $entries = ($entries | update $idx {
                path: $abs_path,
                hourly: $new_hourly,
                daily: $new_daily,
                monthly: $new_monthly,
                ts: $now
            })
        } else {
            # New entry
            $entries = ($entries | append {
                path: $abs_path,
                hourly: 1.0,
                daily: 1.0,
                monthly: 1.0,
                ts: $now
            })
        }
    }

    # Write back
    $entries
    | each { |e| $"($e.path):($e.hourly):($e.daily):($e.monthly):($e.ts)" }
    | str join "\n"
    | save -f $history_file
}

# Get recent files sorted by score
def recentf-get [] {
    let history_file = ($RECENTF_FILE | path expand)
    let now = (date now | into int) // 1_000_000_000

    if not ($history_file | path exists) {
        return []
    }

    open $history_file
    | lines
    | where { $in | str length | $in > 0 }
    | each { |line|
        let parts = ($line | split column ":" path hourly daily monthly ts)
        if ($parts | length) > 0 {
            let elapsed = $now - ($parts.ts.0 | into int)
            let h = ($parts.hourly.0 | into float) * (2 ** (-1 * $elapsed / $RECENTF_HOURLY_HALF))
            let d = ($parts.daily.0 | into float) * (2 ** (-1 * $elapsed / $RECENTF_DAILY_HALF))
            let m = ($parts.monthly.0 | into float) * (2 ** (-1 * $elapsed / $RECENTF_MONTHLY_HALF))
            let score = ($h * $RECENTF_HOURLY_WEIGHT) + ($d * $RECENTF_DAILY_WEIGHT) + ($m * $RECENTF_MONTHLY_WEIGHT)
            {path: $parts.path.0, score: $score}
        } else {
            null
        }
    }
    | where { $in != null }
    | sort-by score -r
    | get path
}

# Get recent files for current directory
def recentf-get-cwd [] {
    let cwd = $"($env.PWD)/"
    recentf-get
    | where { $in | str starts-with $cwd }
    | each { |p|
        let rel = ($p | str replace $cwd "")
        # Strip trailing slash for consistency
        $rel | str trim -r -c "/"
    }
    | where { $in | path exists }
}

# Clear recent files history
def recentf-purge [] {
    let history_file = ($RECENTF_FILE | path expand)
    rm -f $history_file
}

# =============================================================================

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

