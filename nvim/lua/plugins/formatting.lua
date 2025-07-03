return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      markdown = { "dprint" },
      html = { "dprint" },
      python = { "dprint" },
      sql = { "pg_format" },
      svelte = { "dprint" },
      javascript = { "dprint" },
      typescript = { "dprint" },
      javascriptreact = { "dprint" },
      typescriptreact = { "dprint" },
      json = { "dprint" },
      fish = { "fish_indent" },
      sh = { "shfmt" },
    },

    formatters = {
      dprint = {
        condition = function(ctx)
          return vim.fs.find({ "dprint.json" }, { path = ctx.filename, upward = true })[1]
        end,
      },
    },
  },
}
