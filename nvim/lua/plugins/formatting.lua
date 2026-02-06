local dprint_supported = {
  "markdown",
  "html",
  "python",
  "svelte",
  "javascript",
  "typescript",
  "javascriptreact",
  "typescriptreact",
  "json",
  "toml",
}

local oxfmt_supported = {
  "javascript",
  "typescript",
  "javascriptreact",
  "typescriptreact",
  "json",
  "markdown",
  "html",
}

return {
  {
    -- https://github.com/stevearc/conform.nvim
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters = opts.formatters or {}

      -- Add oxfmt for supported filetypes (inserted first for priority)
      for _, ft in ipairs(oxfmt_supported) do
        opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
        table.insert(opts.formatters_by_ft[ft], "oxfmt")
      end

      -- Add dprint for supported filetypes
      for _, ft in ipairs(dprint_supported) do
        opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
        table.insert(opts.formatters_by_ft[ft], "dprint")
      end

      -- For filetypes with both oxfmt and dprint, stop after first match
      for _, ft in ipairs(oxfmt_supported) do
        if opts.formatters_by_ft[ft] then
          opts.formatters_by_ft[ft].stop_after_first = true
        end
      end

      opts.formatters.oxfmt = {
        command = "oxfmt",
        args = { "--stdin-filepath", "$FILENAME" },
        stdin = true,
        condition = function(ctx)
          return vim.fs.find({ ".oxfmtrc.json", ".oxfmtrc.jsonc" }, { path = ctx.filename, upward = true })[1]
        end,
      }

      opts.formatters.dprint = {
        condition = function(ctx)
          return vim.fs.find({ "dprint.json" }, { path = ctx.filename, upward = true })[1]
        end,
      }
    end,
  },
  {
    -- https://github.com/stevearc/conform.nvim
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sql = { "pg_format" },
        fish = { "fish_indent" },
        sh = { "shfmt" },
        swift = { "swift" },
      },
    },
  },
}
