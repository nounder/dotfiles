local Snacks = require("snacks")

return {
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      {
        "<leader>gg",
        "<cmd>Neogit kind=replace<CR>",
        desc = "Open Git status (full)",
      },
    },
  },

  {
    "lewis6991/gitsigns.nvim",
    opts = {
      word_diff = true,
    },
    init = function()
      -- Set highlight using LazyVim's init approach - runs before plugin loads
      vim.api.nvim_set_hl(0, "GitSignsDeleteVirtLn", {
        bg = "#3d1a1a",
      })
    end,
  },

  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
    },
  },

  {
    "ruifm/gitlinker.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- required
    },
  },

  {
    "tpope/vim-fugitive",
    keys = {
      {
        "<leader>gb",
        "<cmd>G blame<CR>",
      },
      {
        "<leader>gc",
        "<cmd>G commit<CR>",
      },
      {
        "<leader>gd",
        "<cmd>G diff<CR>",
      },
      {
        "<leader>gl",
        "<cmd>G log<CR>",
      },
      {
        "<leader>gx",
        "<cmd>Gvdiff<CR>",
      },
      -- {
      --   "<leader>gg",
      --   "<cmd>tabnew | Git | only<CR>",
      --   desc = "Open Git status (full)",
      -- },
      {
        "<leader>gp",
        "<cmd>Git push<CR>",
        desc = "Git push",
      },
      {
        "<leader>gP",
        "<cmd>Git pull<CR>",
        desc = "Git pull",
      },

      {
        "<leader>gP",
        "<cmd>Git pull<CR>",
        desc = "Git pull",
      },
      {
        "<leader>gb",
        Snacks.picker.git_branches,
        desc = "Git pull",
      },
      {
        "<leader>gB",
        "<Cmd>G blame<CR>",
        desc = "Git blame",
      },
      {
        "<leader>gs",
        Snacks.picker.git_status,
        desc = "Git status",
      },
      {
        "<leader>gll",
        Snacks.picker.git_log_line,
        desc = "Git pull",
      },
      {
        "<leader>glf",
        Snacks.picker.git_log_file,
        desc = "Git pull",
      },
      {
        "<leader>gll",
        Snacks.picker.git_log_line,
        desc = "Git pull",
      },
      {
        "<leader>gd",
        Snacks.picker.git_diff,
        desc = "Git pull",
      },
    },
  },
  {
    -- Adds :GBrowse command
    -- Adds omni-completion for git messages
    "tpope/vim-rhubarb",
    dependencies = {
      "tpope/vim-fugitive", -- required
    },
  },
  {
    -- Adds :GitConflict* commands
    "akinsho/git-conflict.nvim",
    version = "*",
    config = true,
  },
}
