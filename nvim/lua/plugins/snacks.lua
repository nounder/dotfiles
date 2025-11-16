local function sim(chars)
  local keys = vim.api.nvim_replace_termcodes(chars, true, false, true)

  return function()
    vim.api.nvim_feedkeys(keys, "m", true)
  end
end

return {
  {
    -- https://github.com/folke/snacks.nvim
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
        win = {
          input = {
            keys = {
              ["<Esc>"] = { "close", mode = { "n", "i" } },
            },
          },
        },
      },
      dashboard = {
        enabled = false,
      },
      notifier = {
        enabled = false,
      },
    },
    keys = {
      { "ff", sim("<leader>ff"), expr = true },
      { "fr", sim("<leader>fr"), expr = true },

      {
        "<leader>fo",
        function()
          Snacks.picker.resume({})
        end,
        desc = "Resume",
      },
      { "fo", sim("<leader>fo"), expr = true },

      {
        "<leader>fl",
        function()
          Snacks.picker.lines({
            layout = "ivy_split",
          })
        end,
        desc = "Resume",
      },
      { "fl", sim("<leader>fl"), expr = true },

      {
        "<leader>fe",
        function()
          Snacks.explorer()
        end,
      },
    },
  },
}
