return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        -- svelte ls will be automatically installed with mason and loaded with lspconfig
        svelte = {},
      },
    },
  },
}
