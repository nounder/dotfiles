-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file contains definitions of custom general and Leader mappings.

-- General mappings ===========================================================

-- Use this section to add custom general mappings. See `:h vim.keymap.set()`.

-- An example helper to create a Normal mode mapping
local nmap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set("n", lhs, rhs, { desc = desc })
end
-- Same, but for Normal + Visual modes at once (handy for register tweaks).
local nxmap = function(lhs, rhs, desc)
  vim.keymap.set({ "n", "x" }, lhs, rhs, { desc = desc })
end
-- Insert mode mapping helper.
local imap = function(lhs, rhs, desc)
  vim.keymap.set("i", lhs, rhs, { desc = desc })
end

-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap("[p", '<Cmd>exe "put! " . v:register<CR>', "Paste Above")
nmap("]p", '<Cmd>exe "put "  . v:register<CR>', "Paste Below")

-- `q` quits the window (`:q`). This overrides the built-in macro-recording
-- prefix, so `q{reg}` no longer starts recording.
nmap("q", "<Cmd>q<CR>", "Quit window")

-- `<CR>` (Normal) saves the file, mirroring '~/dotfiles/nvim'. In special
-- buffers (quickfix, help, prompts, Neogit, mini pickers, etc.) `<CR>` keeps its
-- native meaning (select item, jump to result, confirm). The check happens at
-- keypress time via a `<expr>` map, so there's no autocmd timing race with
-- plugins that set their own `<CR>` mapping.
local cr_native_buftypes = { quickfix = true, nofile = true, prompt = true, help = true, terminal = true }
local function cr_save()
  -- Return the keys to feed: native `<CR>` in special buffers, else write+esc.
  if cr_native_buftypes[vim.bo.buftype] then
    return "<CR>"
  end
  return "<Cmd>w<CR><Esc>"
end
vim.keymap.set("n", "<CR>", cr_save, { expr = true, desc = "Save file" })

-- `<CR>q` saves and quits (chord, as in dotfiles). NOTE: a chord makes a bare
-- `<CR>` wait for 'timeoutlen' to see if `q` follows; `Q` (above) is the no-wait
-- way to quit. Drop this line if the save-on-Enter delay bothers you.
vim.keymap.set("n", "<CR>q", "<Cmd>wq<CR><Esc>", { desc = "Save & quit" })

-- Window navigation aliases (in addition to 'mini.basics' `<C-hjkl>`).
nmap(";;", "<C-w>w", "Other window")
nmap("gl", "<C-w>w", "Other window")
-- Quick vertical split. (`\` alone is the 'mini.basics' option-toggle prefix,
-- so this uses <Leader>\ to avoid clobbering it.)
nmap("<Leader>\\", "<C-w>v", "Vertical split")

-- `;q` to delete the current buffer (mirrors the `<Leader>bd` buffer-delete).
nmap(";q", "<Cmd>lua MiniBufremove.delete()<CR>", "Delete buffer")

-- `;a` as a quick insert/escape toggle: enter Insert from Normal, leave from Insert.
nmap(";a", "i", "Enter insert")
imap(";a", "<Esc>", "Leave insert")

-- `f` finder prefix (no Leader), ported from '~/dotfiles/nvim'. The forward
-- `f{char}` motion is disabled in 'plugin/30_mini.lua' to free this prefix;
-- `F`/`t`/`T` remain mini.jump motions. Uses 'mini.pick' as the picker backend.
-- This mirrors the `<Leader>f*` "Find" group (defined later) onto bare `f*` for
-- faster access. Two keys keep their original bare-`f` meaning and intentionally
-- differ from `<Leader>f*`: `fr` (recent files, not resume) and `fo` (resume).
nmap("f/", '<Cmd>Pick history scope="/"<CR>',          '"/" history')
nmap("f:", '<Cmd>Pick history scope=":"<CR>',          '":" history')
nmap("fa", '<Cmd>Pick git_hunks scope="staged"<CR>',   "Added hunks (all)")
nmap("fA", '<Cmd>Pick git_hunks path="%" scope="staged"<CR>', "Added hunks (buf)")
nmap("fb", '<Cmd>Pick buffers<CR>',                    "Buffers")
nmap("fc", '<Cmd>Pick git_commits<CR>',                "Commits (all)")
nmap("fC", '<Cmd>Pick git_commits path="%"<CR>',       "Commits (buf)")
nmap("fd", '<Cmd>Pick diagnostic scope="all"<CR>',     "Diagnostic workspace")
nmap("fD", '<Cmd>Pick diagnostic scope="current"<CR>', "Diagnostic buffer")
nmap("ff", '<Cmd>Pick files<CR>',                      "Find files")
nmap("fg", '<Cmd>Pick grep_live<CR>',                  "Grep live")
nmap("fG", '<Cmd>Pick grep pattern="<cword>"<CR>',     "Grep current word")
nmap("fh", '<Cmd>Pick help<CR>',                       "Help tags")
nmap("fH", '<Cmd>Pick hl_groups<CR>',                  "Highlight groups")
nmap("fl", '<Cmd>Pick buf_lines scope="all"<CR>',      "Lines (all)")
nmap("fL", '<Cmd>Pick buf_lines scope="current"<CR>',  "Lines (buf)")
nmap("fm", '<Cmd>Pick git_hunks<CR>',                  "Modified hunks (all)")
nmap("fM", '<Cmd>Pick git_hunks path="%"<CR>',         "Modified hunks (buf)")
nmap("fo", '<Cmd>Pick resume<CR>',                     "Resume picker")
nmap("fr", '<Cmd>Pick oldfiles<CR>',                   "Recent files")
nmap("fR", '<Cmd>Pick lsp scope="references"<CR>',     "References (LSP)")
nmap("fs", '<Cmd>Pick lsp scope="workspace_symbol_live"<CR>', "Symbols workspace (live)")
nmap("fS", '<Cmd>Pick lsp scope="document_symbol"<CR>', "Symbols document")
nmap("fv", '<Cmd>Pick visit_paths cwd=""<CR>',         "Visit paths (all)")
nmap("fV", '<Cmd>Pick visit_paths<CR>',                "Visit paths (cwd)")

-- Delete word backward in Insert mode with Alt+Backspace.
imap("<M-BS>", "<C-w>", "Delete word backward")

-- Don't clobber the unnamed register when deleting/changing small bits of text:
-- route `x` and `c` to the black-hole register (see `:h quote_`).
nxmap("x", '"_x', "Delete char (black hole)")
nxmap("c", '"_c', "Change (black hole)")

-- `Y` (Normal) yanks the whole buffer.
nmap("Y", "<Cmd>%y<CR>", "Yank whole buffer")

-- `z`` toggles the quote style of the string under the cursor (JS/TS family):
-- `'single'` -> `"double"` -> `` `template` `` -> `"double"`.
nmap("z`", function()
  require("string-converter").toggle_string_quotes()
end, "Toggle string quotes")

-- Many general mappings are created by 'mini.basics'. See 'plugin/30_mini.lua'

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- Leader mappings ============================================================

-- Neovim has the concept of a Leader key (see `:h <Leader>`). It is a configurable
-- key that is primarily used for "workflow" mappings (opposed to text editing).
-- Like "open file explorer", "create scratch buffer", "pick from buffers".
--
-- In 'plugin/10_options.lua' <Leader> is set to <Space>, i.e. press <Space>
-- whenever there is a suggestion to press <Leader>.
--
-- This config uses a "two key Leader mappings" approach: first key describes
-- semantic group, second key executes an action. Both keys are usually chosen
-- to create some kind of mnemonic.
-- Example: `<Leader>f` groups "find" type of actions; `<Leader>ff` - find files.
-- Use this section to add Leader mappings in a structural manner.
--
-- Usually if there are global and local kinds of actions, lowercase second key
-- denotes global and uppercase - local.
-- Example: `<Leader>fs` / `<Leader>fS` - find workspace/document LSP symbols.
--
-- Many of the mappings use 'mini.nvim' modules set up in 'plugin/30_mini.lua'.

-- Create a global table with information about Leader groups in certain modes.
-- This is used to provide 'mini.clue' with extra clues.
-- Add an entry if you create a new group.
-- NOTE: the `<Leader>a` "+AI" group is registered in 'plugin/60_agentic.lua'
-- (it appends to this table at source time, before 'mini.clue' setup runs).
Config.leader_group_clues = {
  { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
  { mode = 'n', keys = '<Leader>e', desc = '+Explore/Edit' },
  { mode = 'n', keys = '<Leader>f', desc = '+Find' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader>l', desc = '+Language' },
  { mode = 'n', keys = '<Leader>m', desc = '+Map' },
  { mode = 'n', keys = '<Leader>o', desc = '+Other' },
  { mode = 'n', keys = '<Leader>s', desc = '+Session' },
  { mode = 'n', keys = '<Leader>t', desc = '+Terminal' },
  { mode = 'n', keys = '<Leader>v', desc = '+Visits' },

  { mode = 'x', keys = '<Leader>g', desc = '+Git' },
  { mode = 'x', keys = '<Leader>l', desc = '+Language' },
}

-- Helpers for a more concise `<Leader>` mappings.
-- Most of the mappings use `<Cmd>...<CR>` string as a right hand side (RHS) in
-- an attempt to be more concise yet descriptive. See `:h <Cmd>`.
-- This approach also doesn't require the underlying commands/functions to exist
-- during mapping creation: a "lazy loading" approach to improve startup time.
local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end
local xmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc })
end

-- a is for 'AI'. Mappings live with the plugin in 'plugin/60_agentic.lua'
-- (`<Leader>aa` toggle chat, `<Leader>ac` add file/selection to context).
-- The `<Leader>a` "+AI" clue group is registered there too.

-- b is for 'Buffer'. Common usage:
-- - `<Leader>bs` - create scratch (temporary) buffer
-- - `<Leader>ba` - navigate to the alternative buffer
-- - `<Leader>bw` - wipeout (fully delete) current buffer
local new_scratch_buffer = function()
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

nmap_leader('ba', '<Cmd>b#<CR>',                                 'Alternate')
nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>',         'Delete')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>',  'Delete!')
nmap_leader('bs', new_scratch_buffer,                            'Scratch')
nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>',        'Wipeout')
nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')

-- e is for 'Explore' and 'Edit'. Common usage:
-- - `<Leader>ed` - open explorer at current working directory
-- - `<Leader>ef` - open directory of current file (needs to be present on disk)
-- - `<Leader>ei` - edit 'init.lua'
-- - All mappings that use `edit_plugin_file` - edit 'plugin/' config files
local edit_plugin_file = function(filename)
  return string.format('<Cmd>edit %s/plugin/%s<CR>', vim.fn.stdpath('config'), filename)
end
local explore_at_file = '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>'
local explore_quickfix = function()
  vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and 'cclose' or 'copen')
end
local explore_locations = function()
  vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and 'lclose' or 'lopen')
end

nmap_leader('ed', '<Cmd>lua MiniFiles.open()<CR>',          'Directory')
nmap_leader('ef', explore_at_file,                          'File directory')
nmap_leader('ei', '<Cmd>edit $MYVIMRC<CR>',                 'init.lua')
nmap_leader('ek', edit_plugin_file('20_keymaps.lua'),       'Keymaps config')
nmap_leader('em', edit_plugin_file('30_mini.lua'),          'MINI config')
nmap_leader('en', '<Cmd>lua MiniNotify.show_history()<CR>', 'Notifications')
nmap_leader('eo', edit_plugin_file('10_options.lua'),       'Options config')
nmap_leader('ep', edit_plugin_file('40_plugins.lua'),       'Plugins config')
nmap_leader('eq', explore_quickfix,                         'Quickfix list')
nmap_leader('eQ', explore_locations,                        'Location list')

-- f is for 'Fuzzy Find'. Common usage:
-- - `<Leader>ff` - find files; for best performance requires `ripgrep`
-- - `<Leader>fg` - find inside files; requires `ripgrep`
-- - `<Leader>fh` - find help tag
-- - `<Leader>fr` - resume latest picker
-- - `<Leader>fv` - all visited paths; requires 'mini.visits'
--
-- All these use 'mini.pick'. See `:h MiniPick-overview` for an overview.
local pick_added_hunks_buf = '<Cmd>Pick git_hunks path="%" scope="staged"<CR>'
local pick_workspace_symbols_live = '<Cmd>Pick lsp scope="workspace_symbol_live"<CR>'

nmap_leader('f/', '<Cmd>Pick history scope="/"<CR>',            '"/" history')
nmap_leader('f:', '<Cmd>Pick history scope=":"<CR>',            '":" history')
nmap_leader('fa', '<Cmd>Pick git_hunks scope="staged"<CR>',     'Added hunks (all)')
nmap_leader('fA', pick_added_hunks_buf,                         'Added hunks (buf)')
nmap_leader('fb', '<Cmd>Pick buffers<CR>',                      'Buffers')
nmap_leader('fc', '<Cmd>Pick git_commits<CR>',                  'Commits (all)')
nmap_leader('fC', '<Cmd>Pick git_commits path="%"<CR>',         'Commits (buf)')
nmap_leader('fd', '<Cmd>Pick diagnostic scope="all"<CR>',       'Diagnostic workspace')
nmap_leader('fD', '<Cmd>Pick diagnostic scope="current"<CR>',   'Diagnostic buffer')
nmap_leader('ff', '<Cmd>Pick files<CR>',                        'Files')
-- `<Leader><Leader>` (i.e. <Space><Space>) is an alias for `<Leader>ff` so the
-- most common action (find files) is reachable with a double tap of Leader.
nmap_leader(' ', '<Cmd>Pick files<CR>',                         'Files')
nmap_leader('fg', '<Cmd>Pick grep_live<CR>',                    'Grep live')
nmap_leader('fG', '<Cmd>Pick grep pattern="<cword>"<CR>',       'Grep current word')
nmap_leader('fh', '<Cmd>Pick help<CR>',                         'Help tags')
nmap_leader('fH', '<Cmd>Pick hl_groups<CR>',                    'Highlight groups')
nmap_leader('fl', '<Cmd>Pick buf_lines scope="all"<CR>',        'Lines (all)')
nmap_leader('fL', '<Cmd>Pick buf_lines scope="current"<CR>',    'Lines (buf)')
nmap_leader('fm', '<Cmd>Pick git_hunks<CR>',                    'Modified hunks (all)')
nmap_leader('fM', '<Cmd>Pick git_hunks path="%"<CR>',           'Modified hunks (buf)')
nmap_leader('fr', '<Cmd>Pick resume<CR>',                       'Resume')
nmap_leader('fR', '<Cmd>Pick lsp scope="references"<CR>',       'References (LSP)')
nmap_leader('fs', pick_workspace_symbols_live,                  'Symbols workspace (live)')
nmap_leader('fS', '<Cmd>Pick lsp scope="document_symbol"<CR>',  'Symbols document')
nmap_leader('fv', '<Cmd>Pick visit_paths cwd=""<CR>',           'Visit paths (all)')
nmap_leader('fV', '<Cmd>Pick visit_paths<CR>',                  'Visit paths (cwd)')

-- g is for 'Git'. Common usage:
-- - `<Leader>gs` - show information at cursor
-- - `<Leader>go` - toggle 'mini.diff' overlay to show in-buffer unstaged changes
-- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- - `<Leader>gL` - show Git log of current file
local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
local git_log_buf_cmd = git_log_cmd .. ' --follow -- %'

nmap_leader('ga', '<Cmd>Git diff --cached<CR>',             'Added diff')
nmap_leader('gA', '<Cmd>Git diff --cached -- %<CR>',        'Added diff buffer')
nmap_leader('gc', '<Cmd>Git commit<CR>',                    'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>',            'Commit amend')
nmap_leader('gd', '<Cmd>Git diff<CR>',                      'Diff')
nmap_leader('gD', '<Cmd>Git diff -- %<CR>',                 'Diff buffer')
nmap_leader('gg', '<Cmd>Neogit<CR>',                        'Neogit status')
nmap_leader('gl', '<Cmd>' .. git_log_cmd .. '<CR>',         'Log')
nmap_leader('gL', '<Cmd>' .. git_log_buf_cmd .. '<CR>',     'Log buffer')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>', 'Toggle overlay')
nmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>',  'Show at cursor')

xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at selection')

-- References with a single-result shortcut: when there's exactly one reference
-- other than the symbol under the cursor, jump straight to it instead of opening
-- the quickfix list. Servers include the cursor location itself in the results,
-- so we filter it out first ("definition + one use" → a single jump target).
-- Otherwise fall back to the default behavior (populate quickfix + open it). The
-- `on_list` callback replaces the default handler; see `:h on_list`.
local function lsp_references()
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  local cur_lnum = cur_pos[1]
  vim.lsp.buf.references(nil, {
    on_list = function(opts)
      -- Drop the entry pointing at the cursor position itself.
      local others = vim.tbl_filter(function(item)
        local buf = item.bufnr or vim.fn.bufadd(item.filename)
        return not (buf == cur_buf and item.lnum == cur_lnum)
      end, opts.items)

      if #others == 1 then
        vim.fn.setqflist({}, ' ', opts) -- still record full list for `:cnext`/history
        local item = others[1]
        local buf = item.bufnr or vim.fn.bufadd(item.filename)
        vim.fn.bufload(buf)
        vim.api.nvim_win_set_buf(0, buf)
        vim.api.nvim_win_set_cursor(0, { item.lnum, math.max(item.col - 1, 0) })
        vim.cmd('normal! zz')
      else
        vim.fn.setqflist({}, ' ', opts)
        vim.cmd('botright copen')
      end
    end,
  })
end

-- g-prefixed LSP navigation. Set buffer-locally only when a language server
-- attaches (see `:h LspAttach`), so in buffers without LSP these keys keep their
-- built-in behavior. Same scheme as the LazyVim config in '~/dotfiles/nvim':
-- - `gd` - definition;     `gr` - references;  `gI` - implementation
-- - `gy` - type definition; `gD` - declaration
-- - `K`  - hover docs;      `gK` - signature help
Config.new_autocmd('LspAttach', nil, function(ev)
  local buf_map = function(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = ev.buf, desc = 'LSP: ' .. desc })
  end
  buf_map('gd', '<Cmd>lua vim.lsp.buf.definition()<CR>',      'Definition')
  buf_map('gr', lsp_references,                              'References')
  buf_map('gI', '<Cmd>lua vim.lsp.buf.implementation()<CR>',  'Implementation')
  buf_map('gy', '<Cmd>lua vim.lsp.buf.type_definition()<CR>', 'Type definition')
  buf_map('gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>',     'Declaration')
  buf_map('K',  '<Cmd>lua vim.lsp.buf.hover()<CR>',           'Hover')
  buf_map('gK', '<Cmd>lua vim.lsp.buf.signature_help()<CR>',  'Signature help')
end, 'Set buffer-local g-prefixed LSP mappings')

-- l is for 'Language'. Common usage:
-- - `<Leader>ld` - show more diagnostic details in a floating window
-- - `<Leader>lr` - perform rename via LSP
-- - `<Leader>ls` - navigate to source definition of symbol under cursor
--
-- These `<Leader>l*` mappings duplicate the `g`-prefixed ones above as a more
-- discoverable, always-available alternative (they no-op when no server is
-- attached). Keep both in sync when changing actions.
nmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>',     'Actions')
nmap_leader('ld', '<Cmd>lua vim.diagnostic.open_float()<CR>',   'Diagnostic popup')
nmap_leader('lf', '<Cmd>lua require("conform").format()<CR>',   'Format')
nmap_leader('li', '<Cmd>lua vim.lsp.buf.implementation()<CR>',  'Implementation')
nmap_leader('lh', '<Cmd>lua vim.lsp.buf.hover()<CR>',           'Hover')
nmap_leader('ll', '<Cmd>lua vim.lsp.codelens.run()<CR>',        'Lens')
nmap_leader('lr', '<Cmd>lua vim.lsp.buf.rename()<CR>',          'Rename')
nmap_leader('lR', lsp_references,                              'References')
nmap_leader('ls', '<Cmd>lua vim.lsp.buf.definition()<CR>',      'Source definition')
nmap_leader('lt', '<Cmd>lua vim.lsp.buf.type_definition()<CR>', 'Type definition')

xmap_leader('lf', '<Cmd>lua require("conform").format()<CR>', 'Format selection')

-- m is for 'Map'. Common usage:
-- - `<Leader>mt` - toggle map from 'mini.map' (closed by default)
-- - `<Leader>mf` - focus on the map for fast navigation
-- - `<Leader>ms` - change map's side (if it covers something underneath)
nmap_leader('mf', '<Cmd>lua MiniMap.toggle_focus()<CR>', 'Focus (toggle)')
nmap_leader('mr', '<Cmd>lua MiniMap.refresh()<CR>',      'Refresh')
nmap_leader('ms', '<Cmd>lua MiniMap.toggle_side()<CR>',  'Side (toggle)')
nmap_leader('mt', '<Cmd>lua MiniMap.toggle()<CR>',       'Toggle')

-- o is for 'Other'. Common usage:
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>', 'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',    'Trim trailspace')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',          'Zoom toggle')

-- s is for 'Session'. Common usage:
-- - `<Leader>ss` - restore the current directory's session (LazyVim `<Space>qs`)
-- - `<Leader>sn` - start new session
-- - `<Leader>sr` - read previously started session
-- - `<Leader>sd` - delete previously started session
local session_new = 'vim.ui.input({ prompt = "Session name: " }, MiniSessions.write)'

-- Restore the current working directory's session. It is stored in the global
-- sessions directory (keyed by cwd) and auto-saved on exit by the `VimLeavePre`
-- autocommand in 'plugin/30_mini.lua'; `Config.cwd_session_name()` /
-- `cwd_session_path()` are the shared helpers defined there. If no session exists
-- for the cwd, fall back to the read picker.
-- `force=true` discards unsaved buffers like LazyVim does when restoring.
Config.restore_cwd_session = function()
  if vim.fn.filereadable(Config.cwd_session_path()) == 1 then
    Config.restore_session(Config.cwd_session_name())
  else
    MiniSessions.select('read')
  end
end
nmap_leader('ss', '<Cmd>lua Config.restore_cwd_session()<CR>', 'Restore (cwd)')
nmap_leader('sd', '<Cmd>lua MiniSessions.select("delete")<CR>', 'Delete')
nmap_leader('sn', '<Cmd>lua ' .. session_new .. '<CR>',         'New')
nmap_leader('sr', '<Cmd>lua MiniSessions.select("read")<CR>',   'Read')
nmap_leader('sw', '<Cmd>lua MiniSessions.write()<CR>',          'Write current')

-- t is for 'Terminal'
nmap_leader('tT', '<Cmd>horizontal term<CR>', 'Terminal (horizontal)')
nmap_leader('tt', '<Cmd>vertical term<CR>',   'Terminal (vertical)')

-- `<C-`>` opens a split terminal from Normal mode, and jumps back to the editor
-- from inside a terminal. Same key both ways, mirroring the dotfiles `<C-'>`.
vim.keymap.set('n', '<C-`>', '<Cmd>vertical term<CR>',  { desc = 'Terminal (split)' })
vim.keymap.set('t', '<C-`>', [[<C-\><C-n><C-w>p]],       { desc = 'Back to editor' })

-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - add    "core" label to current file.
-- - `<Leader>vV` - remove "core" label to current file.
-- - `<Leader>vc` - pick among all files with "core" label.
local make_pick_core = function(cwd, desc)
  return function()
    local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
    local local_opts = { cwd = cwd, filter = 'core', sort = sort_latest }
    MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
  end
end

nmap_leader('vc', make_pick_core('',  'Core visits (all)'),       'Core visits (all)')
nmap_leader('vC', make_pick_core(nil, 'Core visits (cwd)'),       'Core visits (cwd)')
nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>',    'Add "core" label')
nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>',          'Add label')
nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>',       'Remove label')
-- stylua: ignore end
