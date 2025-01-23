return {
  {
    "zbirenbaum/copilot.lua",
    opts = {
      filetypes = {
        ["."] = false,
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
          -- handled by link
          accept = false,
          next = "<C-]>",
          prev = "<C-[>",
          dismiss = "<C-\\>",
        },
      },
    },
  },
}
