return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    enabled = function()
      return os.getenv("ANTHROPIC_API_KEY") ~= nil or os.getenv("OPENAI_API_KEY") ~= nil
    end,
    version = false, -- set this if you want to always pull the latest change

    opts = {
      hints = {
        enabled = false,
      },
    },

    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons

      {
        -- Make sure to set this up properly if you have lazy=true
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },
}
