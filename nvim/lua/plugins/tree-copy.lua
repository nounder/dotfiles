return {
  {
    -- https://github.com/nounder/tree-copy.nvim
    "nounder/tree-copy.nvim",
    dev = true,
    config = function()
      require("tree-copy").setup()
    end,
    keys = {
      {
        "Y",
        function()
          require("tree-copy").copy_related_code()
        end,
        mode = "v",
        desc = "Copy related code",
      },
    },
  },
}
