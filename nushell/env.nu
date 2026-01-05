# env.nu

$env.TERM = "xterm-256color"

$env.BUN_AGENT_RULE_DISABLED = "1"
$env.CLAUDE_CODE_AGENT_RULE_DISABLED = "1"

$env.SHELL = "/opt/homebrew/bin/nu"

$env.EDITOR = "hx"

$env.FZF_DEFAULT_OPTS = '--cycle --layout=default --height=90% --preview-window=wrap --marker="*" --no-scrollbar --preview-window=border-left'

$env.XDG_CONFIG_HOME = $"($env.HOME)/.config"

$env.HOMEBREW_PREFIX = "/opt/homebrew"
$env.HOMEBREW_CELLAR = "/opt/homebrew/Cellar"
$env.HOMEBREW_REPOSITORY = "/opt/homebrew"

# PATH configuration
$env.PATH = (
    $env.PATH
    | prepend [
        $"($env.HOME)/dotfiles/bin"
        $"($env.HOME)/.bun/bin"
        $"($env.HOME)/.cargo/bin"
        $"($env.HOME)/.local/bin"
        $"($env.HOME)/bin"
        $"($env.HOME)/.deno/bin"
        /usr/local/bin
        /opt/homebrew/bin
        /opt/homebrew/sbin
        $"($env.HOME)/go/bin"
    ]
    | append [
        $"($env.HOME)/.lmstudio/bin"
        node_modules/.bin
        ../node_modules/.bin
    ]
    | uniq
)