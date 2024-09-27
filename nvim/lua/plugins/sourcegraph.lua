return {
  {
    "sourcegraph/sg.nvim",
    enabled = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      chat = {
        default_model = "anthropic/claude-3-5-sonnet-20240620",
      },
    },
  },
}
