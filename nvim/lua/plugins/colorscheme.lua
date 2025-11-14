return {
  {
    -- https://github.com/ellisonleao/gruvbox.nvim
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    opts = {
      overrides = {
        DiffAdd = { link = "GruvboxGreen" },
        DiffChange = { link = "GitSignsChange" },
        DiffDelete = { link = "GitSignsDelete" },
        DiffText = { bg = "NONE", fg = "#8cbee2" },
        DiffFile = { link = "GruvboxYellowBold" },
        BlinkCmpGhostText = { link = "GruvboxBg4" },
        NonText = { link = "GruvboxBg4" },
        TreesitterContextBottom = { underline = true, sp = "Gray" },
        FlashLabel = { fg = "#ffffff" },
        StatusLine = { link = "Normal" },
        MsgArea = { link = "GruvboxFg4" },
      },

      transparent_mode = true,
      contrast = "hard",
    },
  },

  {
    -- https://github.com/folke/tokyonight.nvim
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
    -- https://github.com/LazyVim/LazyVim
    "LazyVim/LazyVim",
    priority = 1000,
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
