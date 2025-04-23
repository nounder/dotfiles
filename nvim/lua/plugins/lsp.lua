local nvim_lsp = require("lspconfig")

local is_cwd_deno = vim.loop.fs_stat(vim.loop.cwd() .. "/deno.json") ~= nil
  and vim.loop.fs_stat(vim.loop.cwd() .. "/bun.lock") == nil

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
        float = {
          header = false,
          max_width = 140,
          focusable = true,
          border = "rounded",
        },
      },
      servers = {
        denols = {
          -- enabled = is_cwd_deno,
          enabled = false,
        },
        vtsls = {
          enabled = not is_cwd_deno,
          --cmd = { "deno", "--no-prompt", "-A", "npm:@vtsls/language-server", "--stdio" },
          --cmd = { "bunx", "--bun", "@vtsls/language-server", "--stdio" },
          cmd = { "npx", "-y", "@vtsls/language-server", "--stdio" },
          -- cmd = { "/Users/soji/bin/tsgo-build/tsgo", "lsp", "--stdio" },
          settings = {
            typescript = {
              preferences = {
                importModuleSpecifierEnding = "js",
              },
            },
          },
        },
        emmet_ls = {
          enabled = false,
          --cmd = { "deno", "-A", "--no-prompt", "npm:emmet-ls", "--stdio" },
          cmd = { "bunx", "emmet-ls", "--stdio" },
        },
        svelte = {
          --cmd = { "deno", "--no-prompt", "npm:svelte-language-server", "--stdio" },
          cmd = { "bunx", "svelte-language-server", "--stdio" },
        },
        jsonls = {
          --cmd = { "deno", "-A", "npm:vscode-json-languageserver", "--stdio" },
          cmd = { "bunx", "vscode-json-languageserver", "--stdio" },
        },
        tailwindcss = {
          enabled = true,
          --cmd = { "deno", "-A", "npm:@tailwindcss/language-server", "--stdio" },
          cmd = { "bunx", "@tailwindcss/language-server", "--stdio" },
        },
        yamlls = {
          --cmd = { "deno", "-A", "npm:yaml-language-server", "--stdio" },
          cmd = { "bunx", "yaml-language-server", "--stdio" },
        },
      },
    },
  },
}
