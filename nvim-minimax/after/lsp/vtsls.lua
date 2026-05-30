-- This file configures the 'vtsls' language server.
-- Source: https://github.com/yioneko/vtsls
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`. The table here
-- is MERGED on top of the defaults shipped by 'nvim-lspconfig' (see its
-- 'lsp/vtsls.lua'), so `cmd`, `filetypes`, and `root_dir` are inherited and only
-- need to be set here to override them.
--
-- Requires the `vtsls` CLI tool on `$PATH`. Install with:
--   npm install -g @vtsls/language-server
-- (or via your package manager of choice, e.g. bun/mason).
--
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
return {
  on_attach = function(client, buf_id)
    -- Reduce very long list of triggers for better 'mini.completion' experience
    client.server_capabilities.completionProvider.triggerCharacters = { ".", ":", "<", '"', "'", "/", "@" }

    -- Toggle inlay hints on per-buffer with `<Leader>li`.
    -- The `*.inlayHints.*` settings further down control which hints the
    -- server computes once toggled on.
    vim.lsp.inlay_hint.enable(false, { bufnr = buf_id })
    vim.keymap.set("n", "<Leader>li", function()
      local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf_id })
      vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf_id })
    end, { buffer = buf_id, desc = "Toggle inlay hints" })
  end,
  -- Structure of these settings comes from vtsls, not Neovim.
  -- See https://github.com/yioneko/vtsls for the full list of options.
  settings = {
    -- vtsls-specific options
    vtsls = {
      experimental = {
        -- Group "add missing imports", "remove unused", etc. into one entry
        completion = { enableServerSideFuzzyMatch = true },
      },
    },
    -- These map onto the standard tsserver settings used by VS Code, applied
    -- to both TypeScript and JavaScript.
    typescript = {
      updateImportsOnFileMove = { enabled = "always" },
      suggest = { completeFunctionCalls = true },
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = false },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
    },
    javascript = {
      updateImportsOnFileMove = { enabled = "always" },
      suggest = { completeFunctionCalls = true },
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = false },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
    },
  },
}
