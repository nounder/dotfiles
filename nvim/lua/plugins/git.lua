return {
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
      { "<leader>gr", "<cmd>G read<CR>" },
      { "<leader>gw", "<cmd>G write<CR>" },
      { "<leader>gx", "<cmd>Gvdiff<CR>" },
    },
  },
  {
    "tpope/vim-rhubarb",
    dependencies = {
      "tpope/vim-fugitive", -- required
    },
  },
  { "akinsho/git-conflict.nvim", version = "*", config = true },
}
