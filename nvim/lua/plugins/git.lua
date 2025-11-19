local Snacks = require("snacks")

return {
  {
    -- https://github.com/NeogitOrg/neogit
    "NeogitOrg/neogit",
    cmd = "Neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      disable_hint = true,
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
    -- https://github.com/lewis6991/gitsigns.nvim
    "lewis6991/gitsigns.nvim",
    opts = {
      diff_opts = {
        algorithm = "patience",
      },
    },
    keys = {
      {
        "<leader>ud",
        "<cmd>Gitsigns toggle_deleted<CR>",
        desc = "Toggle deleted lines",
      },
      {
        "<leader>uw",
        "<cmd>Gitsigns toggle_word_diff<CR>",
        desc = "Toggle word diff",
      },
    },
  },

  {
    -- https://github.com/ruifm/gitlinker.nvim
    "ruifm/gitlinker.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- required
    },
  },

  {
    -- https://github.com/tpope/vim-fugitive
    "tpope/vim-fugitive",
    enabled = true,
    keys = {
      {
        "<leader>gb",
        "<cmd>G blame<CR>",
      },
      {
        "<leader>gc",
        "<cmd>G commit<CR>",
      },
      -- {
      --   "<leader>gd",
      --   "<cmd>G diff<CR>",
      -- },
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
    },
  },
  {
    -- https://github.com/tpope/vim-rhubarb
    -- Adds :GBrowse command
    -- Adds omni-completion for git messages
    "tpope/vim-rhubarb",
    dependencies = {
      "tpope/vim-fugitive", -- required
    },
  },
  {
    -- https://github.com/akinsho/git-conflict.nvim
    -- Adds :GitConflict* commands
    "akinsho/git-conflict.nvim",
    version = "*",
    config = true,
  },
}
