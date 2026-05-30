-- This file configures the 'jsonls' language server.
-- Source: https://github.com/microsoft/vscode-json-languageservice
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`. The table here
-- is MERGED on top of the defaults shipped by 'nvim-lspconfig' (see its
-- 'lsp/jsonls.lua'), so `filetypes` and `root_dir` are inherited and only need
-- to be set here to override them. It provides schema-aware validation,
-- completion, and hover for JSON files (e.g. 'package.json', 'tsconfig.json').
--
-- The `cmd` below runs the server through `bunx` (requires `bun` on `$PATH`).
-- `--no-install` makes it fail fast instead of auto-downloading the package, so
-- install it once with:
--   bun add -g vscode-json-languageserver
--   # or: npm install -g vscode-json-languageserver
-- If you prefer to call the global binary directly instead of via `bunx`, use:
--   cmd = { "vscode-json-languageserver", "--stdio" }
--
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
return {
  cmd = { "bunx", "--no-install", "vscode-json-languageserver", "--stdio" },
}
