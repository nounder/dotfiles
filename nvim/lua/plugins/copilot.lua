return {
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
