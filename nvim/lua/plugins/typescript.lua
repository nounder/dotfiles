local is_cwd_deno = vim.loop.fs_stat(vim.loop.cwd() .. "/deno.json") ~= nil
  and vim.loop.fs_stat(vim.loop.cwd() .. "/bun.lock") == nil

return {
  {
    -- https://github.com/neovim/nvim-lspconfig
    "neovim/nvim-lspconfig",

    ---@class PluginLspOpts
    opts = {
      servers = {
        denols = {
          -- enabled = is_cwd_deno,
          enabled = false,
        },
        --tsgo = {},
        vtsls = {
          enabled = true and not is_cwd_deno,
          --cmd = { "deno", "--no-prompt", "-A", "npm:@vtsls/language-server", "--stdio" },
          --cmd = { "bunx", "--bun", "@vtsls/language-server", "--stdio" },
          -- INSTALL: bun i -g @vtsls/language-server
          cmd = { "vtsls", "--stdio" },
          -- cmd = { "/Users/soji/bin/tsgo-build/tsgo", "lsp", "--stdio" },
          settings = {
            typescript = {
              preferences = {
                importModuleSpecifierEnding = "js",
              },
            },
          },
        },
      },
    },
    keys = {
      {
        "K",
        function()
          local original_file = vim.api.nvim_buf_get_name(0)
          vim.lsp.buf.hover()
          vim.defer_fn(function()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
              local config = vim.api.nvim_win_get_config(win)
              -- Find hover window (floating, not a notification)
              if config.relative ~= "" and config.zindex and config.zindex < 100 then
                local buf = vim.api.nvim_win_get_buf(win)
                local ok, conform = pcall(require, "conform")
                if ok then
                  vim.bo[buf].modifiable = true
                  -- Set fake name for dprint config lookup
                  vim.api.nvim_buf_set_name(buf, original_file .. ".hover.ts")
                  conform.format({ bufnr = buf, async = false, formatters = { "dprint" } })
                  vim.api.nvim_buf_set_name(buf, "")
                  vim.bo[buf].modifiable = false
                  vim.bo[buf].modified = false
                end
                return
              end
            end
          end, 200)
        end,
        desc = "Hover with formatting",
        ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
      },
    },
  },
  {
    -- https://github.com/dmmulroy/tsc.nvim
    "dmmulroy/tsc.nvim",
    dev = true,
    cmd = {
      "TSC",
      "TSCStop",
    },
    keys = {
      { "<Space>cw", "<cmd>TSC<cr>", desc = "TypeScript Compile" },
    },
    opts = {
      bin_path = vim.fn.expand("~/.bun/bin/tsgo"),
      --bin_name = "tsgo",
      auto_open_qflist = false,
      use_trouble_qflist = false,
      use_diagnostics = true,
    },
  },
  {
    -- https://github.com/dmmulroy/ts-error-translator.nvim
    "dmmulroy/ts-error-translator.nvim",
    lazy = false,
    opts = {
      auto_attach = true,
      servers = {
        "ts_ls",
        "tsgo",
        "vtsls",
      },
    },
  },
}
