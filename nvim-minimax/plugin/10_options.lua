-- ┌──────────────────────────┐
-- │ Built-in Neovim behavior │
-- └──────────────────────────┘
--
-- This file defines Neovim's built-in behavior. The goal is to improve overall
-- usability in a way that works best with MINI.
--
-- Here `vim.o.xxx = value` sets default value of option `xxx` to `value`.
-- See `:h 'xxx'` (replace `xxx` with actual option name).
--
-- Option values can be customized on a per buffer or window basis.
-- See 'after/ftplugin/' for common example.
--
-- Notes:
-- - Some options (like `:h 'exrc'`) need to be set before this file is sourced.
--   Set them directly at the bottom of the 'init.lua' file.

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- General ====================================================================
vim.g.mapleader = ' ' -- Use `<Space>` as <Leader> key

vim.o.clipboard   = 'unnamedplus'  -- Sync yank/paste with system clipboard
vim.o.mouse       = 'a'            -- Enable mouse
vim.o.mousescroll = 'ver:1,hor:0'  -- 1 line per wheel tick (smooth), no horizontal
vim.o.swapfile    = false          -- No swap files (skip recovery check on load)
vim.o.switchbuf   = 'usetab'       -- Use already opened buffers when switching
vim.o.undofile    = true           -- Enable persistent undo

vim.o.shada = "'100,<50,s10,:1000,/100,@100,h" -- Limit ShaDa file (for startup)

-- Enable all filetype plugins and syntax (if not enabled, for better startup)
vim.cmd('filetype plugin indent on')
if vim.fn.exists('syntax_on') ~= 1 then vim.cmd('syntax enable') end

-- UI =========================================================================
vim.o.breakindent    = true       -- Indent wrapped lines to match line start
vim.o.breakindentopt = 'list:-1'  -- Add padding for lists (if 'wrap' is set)
vim.o.colorcolumn    = '+1'       -- Draw column on the right of maximum width
vim.o.cursorline     = false      -- Don't highlight the current line (cursor only)
vim.o.linebreak      = true       -- Wrap lines at 'breakat' (if 'wrap' is set)
vim.o.list           = true       -- Show helpful text indicators
vim.o.number         = false      -- Don't show line numbers
vim.o.pumheight      = 10         -- Make popup menu smaller
vim.o.ruler          = false      -- Don't show cursor coordinates
vim.o.shortmess      = 'CFIOSWaco' -- Disable completion msgs + intro splash ('I')
vim.o.showmode       = false      -- Don't show mode in command line
vim.o.signcolumn     = 'yes'      -- Always show signcolumn (less flicker)
vim.o.splitbelow     = true       -- Horizontal splits will be below
vim.o.splitkeep      = 'screen'   -- Reduce scroll during window split
vim.o.splitright     = true       -- Vertical splits will be to the right
vim.o.winborder      = 'single'   -- Use border in floating windows
vim.o.wrap           = false      -- Don't visually wrap lines (toggle with \w)

vim.o.cursorlineopt  = 'screenline,number' -- Show cursor line per screen line

-- Special UI symbols. More is set via 'mini.basics' later.
vim.o.fillchars = 'eob: ,fold:╌,stl:─,stlnc:─' -- stl/stlnc:─ fill the statusline gap (active+inactive)
vim.o.listchars = 'extends:…,nbsp:␣,precedes:…,tab:> '

-- Folds (see `:h fold-commands`, `:h zM`, `:h zR`, `:h zA`, `:h zj`)
vim.o.foldlevel   = 10       -- Fold nothing by default; set to 0 or 1 to fold
vim.o.foldmethod  = 'indent' -- Fold based on indent level
vim.o.foldnestmax = 10       -- Limit number of fold levels
vim.o.foldtext    = ''       -- Show text under fold with its highlighting

-- Editing ====================================================================
vim.o.autoindent    = true    -- Use auto indent
vim.o.expandtab     = true    -- Convert tabs to spaces
vim.o.formatoptions = 'rqnl1j'-- Improve comment editing
vim.o.ignorecase    = true    -- Ignore case during search
vim.o.incsearch     = true    -- Show search matches while typing
vim.o.infercase     = true    -- Infer case in built-in completion
vim.o.shiftwidth    = 2       -- Use this number of spaces for indentation
vim.o.smartcase     = true    -- Respect case if search pattern has upper case
vim.o.smartindent   = true    -- Make indenting smart
vim.o.spelloptions  = 'camel' -- Treat camelCase word parts as separate words
vim.o.tabstop       = 2       -- Show tab as this number of spaces
vim.o.virtualedit   = 'block' -- Allow going past end of line in blockwise mode

vim.o.iskeyword = '@,48-57,_,192-255,-' -- Treat dash as `word` textobject part

-- Pattern for a start of numbered list (used in `gw`). This reads as
-- "Start of list item is: at least one special character (digit, -, +, *)
-- possibly followed by punctuation (. or `)`) followed by at least one space".
vim.o.formatlistpat = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]

-- Built-in completion
vim.o.complete    = '.,w,b,kspell'                  -- Use less sources
vim.o.completeopt = 'menuone,noselect,fuzzy,nosort' -- Use custom behavior

-- Autocommands ===============================================================

-- Don't auto-wrap comments and don't insert comment leader after hitting 'o'.
-- Do on `FileType` to always override these changes from filetype plugins.
local f = function() vim.cmd('setlocal formatoptions-=c formatoptions-=o') end
Config.new_autocmd('FileType', nil, f, "Proper 'formatoptions'")

-- There are other autocommands created by 'mini.basics'. See 'plugin/30_mini.lua'.

-- Diagnostics ================================================================

-- Neovim has built-in support for showing diagnostic messages. This configures
-- a more conservative display while still being useful.
-- See `:h vim.diagnostic` and `:h vim.diagnostic.config()`.
-- stylua: ignore end

-- Custom diagnostic display: instead of underlining the code, mark EVERY line a
-- diagnostic spans with a gutter bar (gitsigns-style), so a multi-line error is
-- visible on each of its lines - not just the first. The built-in `signs`
-- handler only marks the start line, so this is a custom `vim.diagnostic`
-- handler. Handlers are driven by `vim.diagnostic` itself (show/hide called on
-- every change), so it stays in sync and cleans up automatically.
MiniDeps.later(function()
  local ns = vim.api.nvim_create_namespace("span_diagnostic_signs")
  local hl = {
    [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
    [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
    [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
    [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
  }

  -- On every diagnostic update `vim.diagnostic` calls `hide` THEN `show`. If
  -- `hide` clears the namespace, the bars vanish for a frame before `show`
  -- redraws them - that's the flicker when editing a line in a span. Fix: never
  -- clear eagerly in `hide`. `show` already reconciles (sets desired in place,
  -- prunes stale), so the update path needs no clearing at all. Only a genuine
  -- "diagnostics turned off" (`vim.diagnostic.hide()`/`reset`, which fires `hide`
  -- with NO following `show`) must clear. Distinguish them by deferring: `hide`
  -- schedules a clear; a `show` in the same tick cancels it. If no `show`
  -- follows, the deferred clear runs and removes the now-stale bars.
  local pending_clear = {}

  local reconcile = function(bufnr, diagnostics)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    -- Track the most severe diagnostic per line so overlapping spans don't stack
    -- signs; the worst severity wins (lower number = more severe).
    local worst = {}
    for _, d in ipairs(diagnostics) do
      local last = math.min(d.end_lnum or d.lnum, line_count - 1)
      for line = d.lnum, last do
        if worst[line] == nil or d.severity < worst[line] then
          worst[line] = d.severity
        end
      end
    end
    -- Stable `id = line + 1` -> re-setting an unchanged bar updates it in place
    -- and never blinks.
    for line, severity in pairs(worst) do
      vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
        id = line + 1, -- 0-based line -> 1-based id (extmark ids must be > 0)
        sign_text = "▎",
        sign_hl_group = hl[severity],
        priority = 9999, -- sit on top of other signs (e.g. mini.diff)
      })
    end
    -- Prune signs whose line is no longer diagnosed.
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})) do
      local id, line = m[1], m[2]
      if worst[line] == nil then
        vim.api.nvim_buf_del_extmark(bufnr, ns, id)
      end
    end
  end

  vim.diagnostic.handlers.span_signs = {
    show = function(_, bufnr, diagnostics, _)
      pending_clear[bufnr] = nil -- cancel any clear queued by the paired `hide`
      reconcile(bufnr, diagnostics)
    end,
    hide = function(_, bufnr)
      -- Defer; a paired `show` (the update path) will cancel this before it runs.
      pending_clear[bufnr] = true
      vim.schedule(function()
        if pending_clear[bufnr] and vim.api.nvim_buf_is_valid(bufnr) then
          pending_clear[bufnr] = nil
          vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
        end
      end)
    end,
  }

  vim.diagnostic.config({
    -- Enable the custom span-sign handler for warnings and errors only (matches
    -- the previous WARN+ sign policy). NOTE: hints/info get no in-buffer marker;
    -- surface them via `<Leader>ld` / `]d` / the `<Leader>fd` picker.
    span_signs = { severity = { min = "WARN", max = "ERROR" } },

    -- Built-in single-line sign handler off; the span handler above replaces it.
    signs = false,

    -- No underline on the code itself; the gutter span bar is the in-buffer cue.
    underline = false,

    -- Inline message text at the end of the offending line. Full message is still
    -- available via `<Leader>ld` (float), `]d`/`[d` (jump), or `<Leader>fd` (picker).
    virtual_lines = false,
    virtual_text = true,

    -- Don't update diagnostics when typing
    update_in_insert = false,
  })
end)
