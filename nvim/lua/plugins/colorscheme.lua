return {
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    opts = {
      overrides = {
        BlinkCmpGhostText = { link = "GruvboxBg4" },
        NonText = { link = "GruvboxBg4" },
        DiffText = { fg = "#1d2021" },
        FlashLabel = { fg = "#ffffff" },
        StatusLine = { link = "Normal" },
        MsgArea = { link = "GruvboxFg4" },
      },

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
