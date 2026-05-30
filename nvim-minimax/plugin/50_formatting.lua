-- ┌────────────┐
-- │ Formatting │
-- └────────────┘
--
-- Programs dedicated to text formatting (a.k.a. formatters) are very useful.
-- Neovim has built-in tools for text formatting (see `:h gq` and `:h 'formatprg'`).
-- They can be used to configure external programs, but it might become tedious.
--
-- The 'stevearc/conform.nvim' plugin is a good and maintained solution for easier
-- formatting setup. This config mirrors the LazyVim setup in
-- '~/dotfiles/nvim/lua/plugins/formatting.lua'.

local add, later = MiniDeps.add, MiniDeps.later

later(function()
	add("stevearc/conform.nvim")

	-- Filetypes handled by 'oxfmt' (preferred) then 'dprint' as fallback.
	local oxfmt_supported = {
		"javascript",
		"typescript",
		"javascriptreact",
		"typescriptreact",
		"json",
		"markdown",
		"html",
	}
	-- Filetypes handled by 'dprint' (in addition to the 'oxfmt' ones above).
	local dprint_supported = {
		"markdown",
		"html",
		"python",
		"svelte",
		"javascript",
		"typescript",
		"javascriptreact",
		"typescriptreact",
		"json",
		"toml",
	}

	-- Build `formatters_by_ft`: oxfmt first (priority), then dprint.
	local formatters_by_ft = {
		lua = { "stylua" },
		sql = { "pg_format" },
		fish = { "fish_indent" },
		sh = { "shfmt" },
		swift = { "swift" },
	}
	for _, ft in ipairs(oxfmt_supported) do
		formatters_by_ft[ft] = formatters_by_ft[ft] or {}
		table.insert(formatters_by_ft[ft], "oxfmt")
	end
	for _, ft in ipairs(dprint_supported) do
		formatters_by_ft[ft] = formatters_by_ft[ft] or {}
		table.insert(formatters_by_ft[ft], "dprint")
	end
	-- For web filetypes with both formatters available, use the first that runs.
	for _, ft in ipairs(oxfmt_supported) do
		formatters_by_ft[ft].stop_after_first = true
	end

	-- Toggle for format-on-save (`<Leader>lf` always formats regardless).
	vim.g.autoformat = true

	-- See also:
	-- - `:h Conform`
	-- - `:h conform-options`
	-- - `:h conform-formatters`
	require("conform").setup({
		default_format_opts = {
			-- Allow formatting from LSP server if no dedicated formatter is available
			lsp_format = "fallback",
		},
		formatters_by_ft = formatters_by_ft,
		-- Per-formatter overrides. oxfmt/dprint only run when their config file is
		-- found upward from the file, matching the LazyVim behavior.
		formatters = {
			oxfmt = {
				command = "oxfmt",
				args = { "--stdin-filepath", "$FILENAME" },
				stdin = true,
				condition = function(ctx)
					return vim.fs.find({ ".oxfmtrc.json", ".oxfmtrc.jsonc" }, { path = ctx.filename, upward = true })[1]
				end,
			},
			dprint = {
				condition = function(ctx)
					return vim.fs.find({ "dprint.json" }, { path = ctx.filename, upward = true })[1]
				end,
			},
		},
		-- Format on save (skips when `vim.g.autoformat` is false). Falls back to
		-- LSP formatting via `default_format_opts.lsp_format = "fallback"`.
		format_on_save = function(_buf)
			if not vim.g.autoformat then
				return nil
			end
			return { timeout_ms = 1000 }
		end,
	})

	-- `<Leader>uf` toggles format-on-save (mirrors LazyVim's toggle).
	vim.keymap.set("n", "<Leader>uf", function()
		vim.g.autoformat = not vim.g.autoformat
		local state = vim.g.autoformat and "enabled" or "disabled"
		vim.notify("Format on save " .. state, vim.log.levels.INFO)
	end, { desc = "Toggle format on save" })
end)
