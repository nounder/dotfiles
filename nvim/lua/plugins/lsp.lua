local is_cwd_deno = vim.loop.fs_stat(vim.loop.cwd() .. "/deno.json") ~= nil

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
          enabled = is_cwd_deno,
        },
        vtsls = {
          enabled = not is_cwd_deno,
          cmd = { "deno", "--no-prompt", "-A", "npm:@vtsls/language-server", "--stdio" },
          settings = {
            typescript = {
              preferences = {
                importModuleSpecifierEnding = "minimal",
              },
            },
          },
        },
        emmet_ls = {
          enabled = false,
          cmd = { "deno", "-A", "--no-prompt", "npm:emmet-ls", "--stdio" },
        },
        svelte = {
          cmd = { "deno", "--no-prompt", "npm:svelte-language-server", "--stdio" },
        },
        jsonls = {
          cmd = { "deno", "-A", "npm:vscode-json-languageserver", "--stdio" },
        },
        tailwindcss = {
          enabled = false,
          cmd = { "deno", "-A", "npm:@tailwindcss/language-server", "--stdio" },
        },
        yamlls = {
          cmd = { "deno", "-A", "npm:yaml-language-server", "--stdio" },
        },
      },
    },
  },
}
