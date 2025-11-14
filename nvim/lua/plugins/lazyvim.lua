local logo = [[
Welcome back, Rafael!
]]

logo = string.rep("\n", 8) .. logo .. "\n\n"

return {
  {
    -- https://github.com/lukas-reineke/indent-blankline.nvim
    "lukas-reineke/indent-blankline.nvim",
    opts = {
      enabled = false,
    },
  },
  {
    -- https://github.com/folke/noice.nvim
    "folke/noice.nvim",
    opts = {
      presets = {
        lsp_doc_border = true,
      },
    },
  },
  {
    -- https://github.com/rcarriga/nvim-notify
    "rcarriga/nvim-notify",
    enabled = false,
  },
  {
    -- https://github.com/nvim-treesitter/nvim-treesitter-context
    "nvim-treesitter/nvim-treesitter-context",
    opts = {
      max_lines = 4,
      --seperator = "─",
      mode = "topline",
    },
    config = function()
      local tsc = require("treesitter-context")
      tsc.disable()
    end,
  },

  {
    -- https://github.com/akinsho/bufferline.nvim
    "akinsho/bufferline.nvim",
    enabled = false,
  },

  {
    -- https://github.com/nvim-neo-tree/neo-tree.nvim
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
  },

  {
    -- https://github.com/nvimdev/dashboard-nvim
    "nvimdev/dashboard-nvim",
    enabled = false,
    opts = {
      config = {
        header = vim.split(logo, "\n"),
      },
    },
  },

  {
    -- https://github.com/nvim-lualine/lualine.nvim
    "nvim-lualine/lualine.nvim",
    enabled = false,
  },
}
