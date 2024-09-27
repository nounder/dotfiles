return {
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
      "sindrets/diffview.nvim", -- optional, diff integration
    },
    opts = {
      disable_hint = true,
    },
    keys = {
      { "<leader>gg", "<cmd>Neogit kind=replace<CR>" },
    },
    config = true,
  },
}
