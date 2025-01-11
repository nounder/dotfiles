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
        update_in_insert = true,
        underline = true,
        signs = false,
      },
      servers = {
        denols = {
          enabled = false,
        },
        emmet_ls = {
          enabled = false,
          cmd = { "deno", "-A", "--no-prompt", "npm:emmet-ls", "--stdio" },
        },
        svelte = {
          cmd = { "deno", "--no-prompt", "npm:svelte-language-server", "--stdio" },
        },
        vtsls = {
          enabled = true,
          cmd = { "deno", "--no-prompt", "-A", "npm:@vtsls/language-server", "--stdio" },
          settings = {
            typescript = {
              preferences = {
                importModuleSpecifierEnding = "minimal",
              },
            },
          },
        },
        jsonls = {
          cmd = { "deno", "-A", "npm:vscode-json-languageserver", "--stdio" },
        },
        tailwindcss = {
          cmd = { "deno", "-A", "npm:@tailwindcss/language-server", "--stdio" },
        },
        yamlls = {
          cmd = { "deno", "-A", "npm:yaml-language-server", "--stdio" },
        },
      },
    },
  },
}
