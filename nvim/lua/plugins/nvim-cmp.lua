return {
  {
    "hrsh7th/nvim-cmp",
    enabled = false,

    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local cmp = require("cmp")

      cmp.setup.filetype("markdown", { enabled = false })

      opts.preselect = cmp.PreselectMode.None

      opts.mapping = cmp.mapping.preset.insert({
        ["<CR>"] = cmp.config.disable,
        ["<S-CR>"] = cmp.mapping.confirm({ select = true }),
        ["<C-l>"] = cmp.mapping.confirm({ select = true }),
        ["<C-j>"] = require("cmp").mapping.select_next_item(),
        ["<C-k>"] = require("cmp").mapping.select_prev_item(),
      })

      opts.sources = {
        { name = "nvim_lsp" },
        { name = "snippets" },
        { name = "buffer" },
        { name = "path" },
      }

      opts.snippet = {
        expand = function(args)
          vim.snippet.expand(args.body)
        end,
      }
    end,
  },
}
