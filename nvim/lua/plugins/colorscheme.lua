return {
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
    },
  },

  {
    "sainnhe/gruvbox-material",
    priority = 1000,
    lazy = false,
    init = function()
      vim.g.gruvbox_material_transparent_background = 2
    end,
  },

  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      transparent_background = true,
    },
  },

  {
    "LazyVim/LazyVim",
    priority = 1000,
    opts = {
      colorscheme = "gruvbox-material",
    },
  },
}
