local Snacks = require("snacks")

return {

  {
    "sindrets/diffview.nvim",
  },
  {
    "ruifm/gitlinker.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- required
    },
  },
  {
    "tpope/vim-fugitive",
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "gitcommit",
        command = "startinsert",
      })
    end,
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
      {
        "<leader>gg",
        "<cmd>tabnew | Git | only<CR>",
        desc = "Open Git status (full)",
      },
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
        "<leader>gs",
        Snacks.picker.git_branches,
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
