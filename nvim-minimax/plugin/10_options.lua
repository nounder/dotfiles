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
-- 'noinsert' (instead of 'noselect') auto-highlights the first candidate
-- without inserting it into the buffer until accepted (`<C-l>` / `<CR>`).
vim.o.completeopt = 'menuone,noinsert,fuzzy,nosort' -- Use custom behavior

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
-- visible on each of its lines - not just the first.
--
-- WHY NOT a `vim.diagnostic` handler: handlers are driven by `M.show`, which
-- ALWAYS runs `M.hide` first. In the real editor the LSP clears/re-publishes
-- across an async server round-trip, and with `update_in_insert=false` an update
-- landing mid-insert runs `hide` and then returns WITHOUT a paired `show`
-- (deferred to InsertLeave). So `hide` blanks the gutter and nothing restores it
-- until the deferred display runs - that gap is the flicker, and no same-tick
-- cancel can close it. We therefore OWN the namespace and never register a
-- handler: the only thing that ever mutates our bars is a real diagnostic change.
--
-- WHY NOT a decoration provider: ephemeral `sign_text` set in `on_line` is
-- silently ignored (the sign column is laid out from persisted signs before
-- per-line ephemeral drawing), so a decoration provider cannot draw a real gutter
-- bar - only `line_hl_group`/`virt_text`. Verified on this Neovim.
--
-- Approach: reconcile persistent extmark signs from `DiagnosticChanged` (fires
-- after diagnostics settle, including on genuine clear). Old bars persist
-- untouched across the LSP gap (extmark gravity keeps them on the right lines as
-- text shifts) and are repositioned/pruned only when new data actually arrives.
MiniDeps.later(function()
  local ns = vim.api.nvim_create_namespace("span_diagnostic_signs")
  local hl = {
    [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
    [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
    [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
    [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
  }

  local reconcile = function(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    -- WARN..ERROR only (matches the previous sign policy). Hints/info get no
    -- in-buffer marker; surface them via `<Leader>ld` / `]d` / `<Leader>fd`.
    local diagnostics = vim.diagnostic.get(bufnr, {
      severity = { min = vim.diagnostic.severity.WARN, max = vim.diagnostic.severity.ERROR },
    })
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
        priority = 9999, -- sit on top of other signs (mini.diff uses 199)
      })
    end
    -- Prune signs whose line is no longer diagnosed (also clears everything on a
    -- genuine empty-set: DiagnosticChanged fires with no diagnostics -> worst={}).
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})) do
      local id, line = m[1], m[2]
      if worst[line] == nil then
        vim.api.nvim_buf_del_extmark(bufnr, ns, id)
      end
    end
  end

  -- `DiagnosticChanged` fires after diagnostics settle - including the genuine
  -- clear (empty-set fires it with zero diagnostics). This is the ONLY driver, so
  -- the async LSP clear->republish gap and the insert-mode defer can never blank
  -- the gutter. `BufEnter` is a one-shot safety reconcile for buffers opened with
  -- diagnostics already present (no DiagnosticChanged fires on plain open).
  vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufEnter" }, {
    desc = "Reconcile diagnostic span signs",
    callback = function(args)
      reconcile(args.buf)
    end,
  })

  vim.diagnostic.config({
    -- Built-in single-line sign handler off; the span-sign reconcile replaces it.
    signs = false,

    -- No underline on the code itself; the gutter span bar is the in-buffer cue.
    underline = false,

    -- Inline message text at the end of the offending line. Full message is still
    -- available via `<Leader>ld` (float), `]d`/`[d` (jump), or `<Leader>fd` (picker).
    virtual_lines = false,
    virtual_text = true,

    -- Don't update diagnostics when typing. Safe to keep: our signs are driven by
    -- DiagnosticChanged, not the handler hide/show, so this no longer causes the
    -- hide-without-show flicker it used to.
    update_in_insert = false,
  })
end)
