return {
  {
    -- https://github.com/MeanderingProgrammer/render-markdown.nvim
    -- disable buffer decorations
    "MeanderingProgrammer/render-markdown.nvim",
    enabled = false,
  },

  {
    -- https://github.com/nounder/markdown-snip.nvim
    "nounder/markdown-snip.nvim",
    dev = false,
    init = function()
      require("markdown-snip").setup_completion()
    end,
    keys = {
      {
        "gd",
        function()
          require("markdown-snip").goto_file()
        end,
        ft = "markdown",
        desc = "Go to file/code block under cursor",
      },
      {
        "<leader>mf",
        function()
          require("markdown-snip").insert_file_reference()
        end,
        ft = "markdown",
        desc = "Go to file/code block under cursor",
      },
    },
  },
}
