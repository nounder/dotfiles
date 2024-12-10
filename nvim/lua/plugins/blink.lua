return {
  {
    "saghen/blink.cmp",

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        preset = "default",

        ["<C-e>"] = { "hide" },
        ["<C-l>"] = { "select_and_accept" },
        ["<C-;>"] = {
          LazyVim.cmp.map({ "snippet_forward", "ai_accept" }),
        },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<C-j>"] = { "select_next", "fallback" },

        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      },
    },
  },
}
