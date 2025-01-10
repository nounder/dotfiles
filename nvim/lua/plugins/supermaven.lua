return {
  {
    "supermaven-inc/supermaven-nvim",
    enabled = function()
      return os.getenv("NVIM_AI_ENABLED") == "true"
    end,
    opts = {
      ignore_filetypes = {
        markdown = true,
        text = true,
      },
    },
  },
}
