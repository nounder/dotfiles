-- ┌──────────┐
-- │ AI chat  │
-- └──────────┘
--
-- This file contains everything for 'carlos-algms/agentic.nvim': installation,
-- setup, and keymaps. It is self-contained so AI tooling can be enabled or
-- removed by touching a single file.
--
-- 'agentic.nvim' is a Neovim chat interface for AI agents that speak the Agent
-- Client Protocol (ACP). It talks to a provider CLI (Claude, Gemini, Codex, ...)
-- which must be installed separately - the plugin does not manage binaries.
-- For Linux clipboard image pasting it additionally needs `wl-clipboard` or `xclip`.
--
-- See https://github.com/carlos-algms/agentic.nvim for all options.

local add, later = MiniDeps.add, MiniDeps.later

-- Register the `<Leader>a` ("+AI") group with 'mini.clue'. This runs at file
-- source time, which happens before any `later()` callback fires - including
-- 'mini.clue' setup() in 'plugin/30_mini.lua'. So appending here is read in time
-- for the clue window to show "+AI" when pressing `<Leader>a`.
vim.list_extend(Config.leader_group_clues, {
  { mode = "n", keys = "<Leader>a", desc = "+AI" },
  { mode = "x", keys = "<Leader>a", desc = "+AI" },
})

-- Install and configure ======================================================
later(function()
  add("carlos-algms/agentic.nvim")

  -- Unlike lazy.nvim's `opts` (which calls `setup()` under the hood), 'mini.deps'
  -- requires an explicit `setup()` call. Setting the provider name is all that is
  -- needed to get started.
  require("agentic").setup({
    provider = "claude-agent-acp",
  })

  -- Move the "generating"/"thinking"/etc. indicator OUT of the chat buffer and
  -- into the chat window's own winbar (the bar the plugin already draws at the
  -- top of each Agentic window). The plugin's default indicator is a 3-row
  -- `virt_lines` extmark pinned to the chat's last line, redrawn every
  -- ~100-600ms; that block growing/shrinking below the content fights the chat's
  -- auto-scroll and makes streaming glitchy. There is no config flag, so patch
  -- the shared `StatusAnimation` class table (affects all instances via
  -- `__index`). Done here, not by editing plugin source, so it survives
  -- `:lua MiniDeps.update()`.
  local ok, StatusAnimation = pcall(require, "agentic.ui.status_animation")
  local ok_wd, WindowDecoration = pcall(require, "agentic.ui.window_decoration")
  if ok and ok_wd then
    -- 1) Kill the glitchy in-buffer render: make the per-frame draw a no-op.
    StatusAnimation._render_frame = function() end

    -- 2) Reflect state in the chat winbar instead. Every spinner change funnels
    --    through `start(state)` / `stop()`. `StatusAnimation` holds `_bufnr` (the
    --    chat buffer), and `render_header(bufnr, "chat", context)` writes the
    --    given `context` into that window's winbar (the plugin's own, supported
    --    mechanism). Pass the live state on start, clear it ("") on stop.
    local orig_start, orig_stop = StatusAnimation.start, StatusAnimation.stop
    StatusAnimation.start = function(self, state)
      orig_start(self, state)
      pcall(WindowDecoration.render_header, self._bufnr, "chat", "· " .. tostring(state))
    end
    StatusAnimation.stop = function(self)
      orig_stop(self)
      pcall(WindowDecoration.render_header, self._bufnr, "chat", "")
    end
  end

  -- Pretty markdown rendering in the chat (bullet/checkbox icons, code-block
  -- treatment, etc.). The chat buffer is already filetype 'AgenticChat' with the
  -- markdown tree-sitter parser started by the plugin, so 'render-markdown.nvim'
  -- just needs that filetype in its `file_types`. Scoped to ONLY 'AgenticChat'
  -- so normal markdown files keep their plain text + tree-sitter highlighting (no
  -- conceal/icon rewriting). Requires the 'markdown'/'markdown_inline' parsers
  -- (auto-installed in 'plugin/40_plugins.lua') and an icon provider
  -- ('mini.icons', set up in 'plugin/30_mini.lua').
  add("MeanderingProgrammer/render-markdown.nvim")
  require("render-markdown").setup({
    file_types = { "AgenticChat" },
    -- Disable heading icons + background band; tree-sitter still colors heading
    -- text. (Matches the disabled-headings preference from '~/dotfiles/nvim'.)
    heading = { enabled = false },
    -- Keep the raw markers VISIBLE: don't conceal `**bold**`, `` `code` ``, etc.
    -- By default render-markdown raises 'conceallevel' to 3 while rendering, which
    -- hides the markers. Pinning the rendered level to 0 leaves them on screen;
    -- the actual bold/italic/inline-code *styling* still comes from tree-sitter.
    win_options = { conceallevel = { rendered = 0 } },
  })

  -- Make rendered backgrounds transparent. render-markdown links its code groups
  -- to bg-having defaults (`RenderMarkdownCode` -> 'ColorColumn'), which paints a
  -- solid band behind code blocks and inline code - clashing with this config's
  -- transparent scheme (see 'plugin/25_colorscheme.lua'). Strip the bg, keeping
  -- the foreground. render-markdown re-defines its colors on `ColorScheme`, so
  -- re-apply then too (and once now). Heading bg groups are moot since headings
  -- are disabled above.
  local strip_md_bg = function()
    vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = "NONE" })
    vim.api.nvim_set_hl(0, "RenderMarkdownCodeInline", { bg = "NONE" })
  end
  Config.new_autocmd("ColorScheme", "*", strip_md_bg, "Transparent render-markdown bg")
  strip_md_bg()

  -- Don't wrap lines in the chat. Wide markdown tables (rendered as padded
  -- virtual text by render-markdown) overflow the narrow chat window; with 'wrap'
  -- on they fold onto the next visual line and the borders/cells mangle. With
  -- 'nowrap' a wide table renders cleanly and simply extends past the right edge.
  -- Trade-off: long prose lines also extend off-screen instead of wrapping.
  -- (Horizontal-scrolling the rendered table isn't possible - it's virtual text,
  -- not real buffer columns - but the left portion stays readable.)
  Config.new_autocmd("FileType", "AgenticChat", function()
    vim.opt_local.wrap = false
  end, "No line wrap in AgenticChat")
end)

-- Keymaps ====================================================================

-- a is for 'AI'. Common usage:
-- - `<Leader>aa` - toggle the AI chat widget
-- - `<Leader>ac` - add current file (Normal) or selection (Visual) to context
-- - `<Leader>as` - stop the current generation (the plugin ships no key for this)
--
-- The chat widget itself defines buffer-local mappings (e.g. `<CR>` / `<C-s>`
-- to submit, `<localLeader>m` to switch model, `q` to close). See its README.
-- stylua: ignore start
vim.keymap.set('n', '<Leader>aa', '<Cmd>lua require("agentic").toggle()<CR>',                           { desc = 'Toggle chat' })
vim.keymap.set('n', '<Leader>ac', '<Cmd>lua require("agentic").add_selection_or_file_to_context()<CR>', { desc = 'Add file to context' })
vim.keymap.set('n', '<Leader>as', '<Cmd>lua require("agentic").stop_generation()<CR>',                  { desc = 'Stop generation' })

vim.keymap.set('x', '<Leader>aa', '<Cmd>lua require("agentic").toggle()<CR>',                           { desc = 'Toggle chat' })
vim.keymap.set('x', '<Leader>ac', '<Cmd>lua require("agentic").add_selection_or_file_to_context()<CR>', { desc = 'Add selection to context' })
-- stylua: ignore end
