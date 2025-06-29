return {
  {
    "markdown-gd",
    dir = vim.fn.stdpath("config") .. "/lua/custom",
    name = "markdown-gd",
    ft = "markdown",
    config = function()
      require("custom.markdown_gd").setup()
    end,
    keys = {
      { "gd", function() require("custom.markdown_gd").goto_file() end, ft = "markdown", desc = "Goto file from fenced block" },
      { "<leader>mf", function() 
        require("snacks").picker.files({
          cwd = vim.fn.expand("%:p:h"),
          confirm = function(picker, item)
            picker:close()
            if item then
              local relative_path = vim.fn.fnamemodify(item.file, ":.")
              local filename = vim.fn.fnamemodify(item.file, ":t")
              local link_text = string.format("[%s](%s)", filename, relative_path)
              vim.api.nvim_put({ link_text }, "c", true, true)
            end
          end,
        })
      end, ft = "markdown", desc = "Insert file link" },
    },
  },
}