-- This file configures the 'pyright' language server.
-- Source: https://github.com/microsoft/pyright
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`. The table here
-- is MERGED on top of the defaults shipped by 'nvim-lspconfig' (see its
-- 'lsp/pyright.lua'), so `cmd`, `filetypes`, and `root_dir` are inherited and
-- only need to be set here to override them. Pyright provides type checking,
-- completion, and hover for Python.
--
-- Requires the `pyright-langserver` CLI on `$PATH`. Install with:
--   npm install -g pyright
--   # or: pipx install pyright
--
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
return {
	settings = {
		python = {
			analysis = {
				-- Analyze only files open in the editor, not the whole workspace, to
				-- keep things fast in large projects. Set to "workspace" for full checks.
				diagnosticMode = "openFilesOnly",
				-- Surface common issues without being overly noisy.
				typeCheckingMode = "basic",
				useLibraryCodeForTypes = true,
				autoImportCompletions = true,
			},
		},
	},
}
