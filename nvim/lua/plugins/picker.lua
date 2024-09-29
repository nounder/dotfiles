return {
  {
    'nvim-telescope/telescope.nvim',

    opts = {
      defaults = {
        layout_strategy = "horizontal",
        mappings = {
          i = {
            ["<esc>"] = "close",
            ["<C-h>"] = "close",
            ["<C-j>"] = "move_selection_next",
            ["<C-k>"] = "move_selection_previous",
            ["<C-l>"] = "file_edit",
          },
        },
      }
    },

    keys = {
      {
        "fr",
        "<leader>sR",
        desc = "Resume",
      },

      {
        "<leader><space>",
        "<leader>ff",
        remap = true,
      },

      {
        "ff",
        "<leader>ff",
        remap = true
      },

      {
        "fF",
        "<leader>fF",
        remap = true,
      },

      {
        "fs",
        "<leader>sS",
        remap = true,
        desc = "Goto Symbol",
      },

      {
        "fS",
        "<leader>ss",
        remap = true,
        desc = "Goto Symbol (Workspace)",
      },
    },
  },

  {
    'mollerhoj/telescope-recent-files.nvim',
    dependencies = {
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      require("telescope").load_extension("recent-files")
    end,
    keys = {
      {
        "<leader>ff",
        function()
          require('telescope').extensions['recent-files'].recent_files({})
        end,
      }
    }
  }
}
