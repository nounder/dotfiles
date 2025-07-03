return {
  {
    -- disable buffer decorations
    "MeanderingProgrammer/render-markdown.nvim",
    enabled = false,
  },

  {
    "nounder/markdown-snip.nvim",
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
