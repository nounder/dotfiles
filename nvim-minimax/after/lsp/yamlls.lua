-- This file configures the 'yamlls' language server.
-- Source: https://github.com/redhat-developer/yaml-language-server
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`. The table here
-- is MERGED on top of the defaults shipped by 'nvim-lspconfig' (see its
-- 'lsp/yamlls.lua'), so `filetypes` and `root_dir` are inherited and only need
-- to be set here to override them. It provides schema-aware validation,
-- completion, and hover for YAML files (e.g. GitHub Actions, docker-compose,
-- Kubernetes manifests) via SchemaStore.
--
-- The `cmd` below runs the server through `bunx` (requires `bun` on `$PATH`).
-- `--no-install` makes it fail fast instead of auto-downloading the package, so
-- install it once with:
--   bun add -g yaml-language-server
--   # or: npm install -g yaml-language-server
-- If you prefer to call the global binary directly instead of via `bunx`, use:
--   cmd = { "yaml-language-server", "--stdio" }
--
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
return {
	cmd = { "bunx", "--no-install", "yaml-language-server", "--stdio" },
}
