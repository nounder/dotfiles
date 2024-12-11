return {
  {
    "sainnhe/gruvbox-material",
    priority = 1000,
    init = function()
      vim.g.gruvbox_material_transparent_background = 2
    end,
  },

  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    config = true,
    opts = {
      transparent_mode = true,
      contrast = "hard",
    },
  },

  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },

  {
    "LazyVim/LazyVim",
    priority = 1000,
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
