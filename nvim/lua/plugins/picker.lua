return {
  {
    "ibhagwan/fzf-lua",

    keys = {
      {
        "fr",
        "<cmd>FzfLua resume<cr>",
        desc = "Resume",
      },

      {
        "<leader><space>",
        LazyVim.pick("files", { root = false, show_untracked = true }),
      },

      {
        "ff",
        LazyVim.pick("files", { root = false, show_untracked = true }),
      },

      {
        "fF",
        LazyVim.pick("auto", { root = true, show_untracked = true }),
      },

      {
        "fs",
        function()
          require("fzf-lua").lsp_document_symbols({})
        end,
        desc = "Goto Symbol",
      },

      {
        "fS",
        function()
          require("fzf-lua").lsp_live_workspace_symbols({})
        end,
        desc = "Goto Symbol (Workspace)",
      },
    },
  },
}
