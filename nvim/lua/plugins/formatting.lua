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

return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      for _, ft in ipairs(dprint_supported) do
        opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
        table.insert(opts.formatters_by_ft[ft], "dprint")
      end

      opts.formatters = opts.formatters or {}
      opts.formatters.dprint = {
        condition = function(ctx)
          return vim.fs.find({ "dprint.json" }, { path = ctx.filename, upward = true })[1]
        end,
      }
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sql = { "pg_format" },
        fish = { "fish_indent" },
        sh = { "shfmt" },
      },
    },
  },
}
