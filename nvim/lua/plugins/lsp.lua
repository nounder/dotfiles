return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      inlay_hints = {
        enabled = false,
      },
      diagnostics = {
        virtual_text = false,
        signs = false,
      },
      servers = {
        svelte = {
          --cmd = { "deno", "run", "-E", "-R", "-S=cpus,homedir,uid", "--allow-run", "--allow-write=.", "--allow-ffi", "npm:svelte-language-server", "--stdio" }
          --cmd = { "deno", "run", "-A", "npm:svelte-language-server", "--stdio" }
          --cmd = { "bunx", "--bun", "svelte-language-server", "--stdio" }
          cmd = { "npx", "svelte-language-server", "--stdio" }
        },
        vtsls = {
          --cmd = { "bunx", "--bun", "@vtsls/language-server", "--stdio" },
          cmd = { "npx", "@vtsls/language-server", "--stdio" },
          settings = {
            typescript = {
              preferences = {
                importModuleSpecifierEnding = "minimal",
              }
            }
          }
        },
        jsonls = {
          cmd = { "npx", "vscode-json-languageserver", "--stdio" }
        },
        tailwindcss = {
          cmd = { "npx", "@tailwindcss/language-server", "--stdio" },
        },
      }
    },
  },
}
