return {
  "rmagatti/auto-session",
  enabled = true,
  lazy = false,
  config = function()
    require("auto-session").setup({})
  end,
}
