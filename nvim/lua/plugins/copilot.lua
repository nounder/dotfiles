return {
  {
    "yetone/avante.nvim",
    enabled = true,
    event = "VeryLazy",
    lazy = false,
    opts = {
      ignore_filetypes = {
        markdown = true,
      },
      hints = {
        enabled = false,
      },
    },
    build = ":AvanteBuild", -- This is optional, recommended tho. Also note that this will block the startup for a bit since we are compiling bindings in Rust.
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
    },
  },

  {
    "supermaven-inc/supermaven-nvim",
    cmd = {
      "SupermavenStart",
    },
    keys = {
      { "<leader>ac", "<cmd>SupermavenStart<cr>", desc = "Enable Supermaven" },
    },
    enabled = true,
    opts = {
      ignore_filetypes = {
        markdown = true,
        toggleterm = true,
      },
      keymaps = {
        accept_suggestion = "<C-;>",
        accept_word = "<C-j>",
      },
    },
    -- config = function()
    --   require("supermaven-nvim").setup({})
    -- end,
  },
  {
    "zbirenbaum/copilot.lua",
    enabled = false,
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<C-;>",
        },
      },
      panel = {
        enabled = true,
        auto_refresh = false,
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<M-CR>",
        },
        layout = {
          position = "bottom", -- | top | left | right
          ratio = 0.4,
        },
      },
      filetypes = {
        markdown = false,
        help = false,
      },
    },
  },
}
