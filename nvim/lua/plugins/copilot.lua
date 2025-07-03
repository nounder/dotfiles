return {
  {
    "zbirenbaum/copilot.lua",
    enabled = not vim.env.NVIM_LIGHTWEIGHT,
    opts = {
      filetypes = {
        text = false,
        markdown = false,
        javascript = true,
        typescript = true,
        sh = true,
        lua = true,
        bash = true,
        fish = true,
        go = true,
        zig = true,
        rust = true,
      },

      suggestion = {
        keymap = {
          -- handled by blink
          accept = false,
          next = "<C-]>",
          prev = "<C-[>",
          dismiss = "<C-\\>",
        },
      },
    },
  },

  {
    "olimorris/codecompanion.nvim",
    enabled = not vim.env.NVIM_LIGHTWEIGHT,
    opts = {},
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
  },

  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        per_filetype = {
          codecompanion = { "codecompanion" },
        },
      },
    },
  },
}
