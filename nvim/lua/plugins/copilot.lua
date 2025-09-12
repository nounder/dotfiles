return {
  {
    "zbirenbaum/copilot.lua",
    enabled = true and not vim.env.NVIM_LIGHTWEIGHT,
    opts = {
      filetypes = {
        text = false,
        markdown = true,
        javascript = true,
        typescript = true,
        sh = true,
        lua = true,
        bash = true,
        fish = true,
        go = true,
        zig = true,
        rust = true,
      },

      suggestion = {
        keymap = {
          -- handled by blink
          accept = false,
          next = "<C-]>",
          prev = "<C-[>",
          dismiss = "<C-\\>",
        },
      },
    },
  },
}
