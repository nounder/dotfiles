return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-k>",
          node_incremental = "<C-k>",
          scope_incremental = false,
          node_decremental = "<C-j>",
        },
      },

      textobjects = {
        select = {
          enable = true,
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
          },
        },
        move = {
          enable = true,
          set_jumps = true, -- whether to set jumps in the jumplist

          goto_next_start = {
            ["]t"] = "@loop.*",

            ["]s"] = { query = "@scope", query_group = "locals", desc = "Next scope" },
            ["]z"] = { query = "@fold", query_group = "folds", desc = "Next fold" },
          },

          goto_next_end = {},

          goto_previous_start = {
            ["[t"] = "@loop.*",
          },

          goto_previous_end = {
            ["[M"] = "@function.outer",
          },

          goto_next = {
            ["]c"] = "@conditional.outer",
          },

          goto_previous = {
            ["[c"] = "@conditional.outer",
          },
        },
      },
    },
  },
}
