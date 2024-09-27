return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      inlay_hints = {
        enabled = false,
      },
      diagnostics = {
        virtual_text = false,
        signs = false,
      },
    },
  },
}
