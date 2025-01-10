local logo = [[
Welcome back, Rafael!
]]

logo = string.rep("\n", 8) .. logo .. "\n\n"

return {
  {
    "lukas-reineke/indent-blankline.nvim",
    opts = {
      enabled = false,
    },
  },
  {
    "folke/noice.nvim",
    enabled = true,
    opts = {
      presets = {
        lsp_doc_border = true,
      },
    },
  },
  {
    "rcarriga/nvim-notify",
    enabled = false,
  },

  {
    "akinsho/bufferline.nvim",
    enabled = false,
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
  },

  {
    "nvimdev/dashboard-nvim",
    enabled = false,
    opts = {
      config = {
        header = vim.split(logo, "\n"),
      },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    enabled = false,
  },
}
