return {
  -- https://github.com/nvim-mini/mini.files
  "nvim-mini/mini.files",
  enabled = true,
  opts = {
    options = {
      use_as_default_explorer = true,
    },
    content = {
      filter = function(fs_entry)
        return fs_entry.name ~= ".DS_Store"
      end,
    },
  },
  keys = {
    {
      "<leader>e",
      function()
        require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
      end,
      desc = "Open mini.files (Directory of Current File)",
    },
    {
      "<leader>E",
      function()
        require("mini.files").open(vim.uv.cwd(), true)
      end,
      desc = "Open mini.files (cwd)",
    },

    -- {
    --   "fm",
    --   function()
    --     require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
    --   end,
    --   desc = "Open mini.files (Directory of Current File)",
    -- },
    -- {
    --   "fM",
    --   function()
    --     require("mini.files").open(vim.uv.cwd(), true)
    --   end,
    --   desc = "Open mini.files (cwd)",
    -- },
  },
}
