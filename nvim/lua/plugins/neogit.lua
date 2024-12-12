return {
  {
    "NeogitOrg/neogit",
    cmd = {
      "Neogit",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
      "sindrets/diffview.nvim", -- optional, diff integration
    },
    opts = {
      disable_hint = true,
    },
    keys = {
      { "<leader>gg", "<cmd>Neogit<CR>" },
    },
    config = true,
  },
}
