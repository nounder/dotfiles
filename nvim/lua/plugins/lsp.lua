return {
  {
    -- https://github.com/neovim/nvim-lspconfig
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
        float = {
          header = false,
          max_width = 140,
          focusable = true,
          border = "rounded",
        },
      },
      servers = {
        sourcekit = {},
        taplo = {
          enabled = false,
        },
        emmet_ls = {
          enabled = false,
          --cmd = { "deno", "-A", "--no-prompt", "npm:emmet-ls", "--stdio" },
          cmd = { "bunx", "emmet-ls", "--stdio" },
        },
        svelte = {
          enabled = false,
          --cmd = { "deno", "--no-prompt", "npm:svelte-language-server", "--stdio" },
          cmd = { "bunx", "svelte-language-server", "--stdio" },
        },
        jsonls = {
          --cmd = { "deno", "-A", "npm:vscode-json-languageserver", "--stdio" },
          cmd = { "bunx", "vscode-json-languageserver", "--stdio" },
        },
        tailwindcss = {
          enabled = true,
          -- INSTALL: bun i -g @tailwindcss/language-server
          cmd = { "tailwindcss-language-server", "--stdio" },
        },
        yamlls = {
          --cmd = { "deno", "-A", "npm:yaml-language-server", "--stdio" },
          cmd = { "bunx", "yaml-language-server", "--stdio" },
        },
      },
    },
  },
}
