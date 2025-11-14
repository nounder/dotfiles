return {
  {
    -- https://github.com/stevearc/oil.nvim
    "stevearc/oil.nvim",
    enabled = false,
    opts = {
      default_file_explorer = true,
      columns = {
        "icon",
        "size",
      },
      delete_to_trash = true,
      float = {
        max_width = 0.8,
        max_height = 0.9,
      },
    },
    keys = {
      {
        "<space>fm",
        function()
          require("oil").open_float(nil, {
            preview = {
              horziontal = true,
            },
          })
        end,
      },
      {
        "<space>fM",
        "<cmd>Oil<cr>",
      },
    },
  },
}
