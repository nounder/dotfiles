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
    priority = 100,
    keys = {
      { "<leader>gb", "<cmd>G blame<CR>" },
      { "<leader>gc", "<cmd>G commit<CR>" },
      { "<leader>gd", "<cmd>G diff<CR>" },
      { "<leader>gl", "<cmd>G log<CR>" },
      { "<leader>gp", "<cmd>G push<CR>" },
      { "<leader>gx", "<cmd>Gvdiff<CR>" },
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
