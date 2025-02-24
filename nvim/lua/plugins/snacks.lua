local function sim(chars)
  local keys = vim.api.nvim_replace_termcodes(chars, true, false, true)

  return function()
    vim.api.nvim_feedkeys(keys, "m", true)
  end
end

return {
  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      picker = {
        layouts = {
          default = {
            layout = {
              width = 0.99,
            },
          },
          sidebar = {
            layout = {
              position = "right",
            },
          },
        },
      },
      dashboard = {
        enabled = false,
      },
    },
    keys = {
      { "ff", sim("<leader>ff"), expr = true },
      { "fr", sim("<leader>fr"), expr = true },

      { "<leader>fo", "<cmd>FzfLua resume<cr>", desc = "Resume" },
      { "fo", sim("<leader>fo"), expr = true },

      { "<leader>fl", "<cmd>FzfLua grep_curbuf<cr>", desc = "Search in Current Buffer" },
      { "fl", sim("<leader>fl"), expr = true },

      { "gf", "<cmd>FzfLua lsp_finder<cr>" },

      {
        "<leader>uz",
        function()
          Snacks.zen()
        end,
      },
      {
        "<leader>fe",
        function()
          Snacks.explorer()
        end,
      },
    },
  },
}
