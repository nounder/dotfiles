-- This file configures the 'tailwindcss' language server.
-- Source: https://github.com/tailwindlabs/tailwindcss-intellisense
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`. The table here
-- is MERGED on top of the defaults shipped by 'nvim-lspconfig' (see its
-- 'lsp/tailwindcss.lua'), so `cmd`, `filetypes`, and `root_dir` are inherited and
-- only need to be set here to override them. By default it attaches in projects
-- that have a Tailwind config or dependency in their root.
--
-- Requires the `tailwindcss-language-server` CLI on `$PATH`. Install with:
--   bun add -g @tailwindcss/language-server
--   # or: npm install -g @tailwindcss/language-server
--
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
return {
	cmd = { "tailwindcss-language-server", "--stdio" },
}
