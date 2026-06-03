-- ┌────────────────────┐
-- │ MINI configuration │
-- └────────────────────┘
--
-- This file contains configuration of the MINI parts of the config.
-- It contains only configs for the 'mini.nvim' plugin (installed in 'init.lua').
--
-- 'mini.nvim' is a library of modules. Each is enabled independently via
-- `require('mini.xxx').setup()` convention. It creates all intended side effects:
-- mappings, autocommands, highlight groups, etc. It also creates a global
-- `MiniXxx` table that can be later used to access module's features.
--
-- Every module's `setup()` function accepts an optional `config` table to
-- adjust its behavior. See the structure of this table at `:h MiniXxx.config`.
--
-- See `:h mini.nvim-general-principles` for more general principles.
--
-- Here each module's `setup()` has a brief explanation of what the module is for,
-- its usage examples (uses Leader mappings from 'plugin/20_keymaps.lua'), and
-- possible directions for more info.
-- For more info about a module see its help page (`:h mini.xxx` for 'mini.xxx').

-- To minimize the time until first screen draw, modules are enabled in two steps:
-- - Step one enables everything that is needed for first draw with `now()`.
--   Sometimes needed only if Neovim is started as `nvim -- path/to/file`.
-- - Everything else is delayed until the first draw with `later()`.
local now, later = MiniDeps.now, MiniDeps.later
local now_if_args = Config.now_if_args

-- Step one ===================================================================
-- The color scheme is set up in its own file: 'plugin/25_colorscheme.lua'
-- (sourced just before this one). It builds 'base16-gruvbox' via 'mini.base16'
-- and applies transparency + highlight overrides.

-- Common configuration presets. Example usage:
-- - `<C-s>` in Insert mode - save and go to Normal mode
-- - `go` / `gO` - insert empty line before/after in Normal mode
-- - `gy` / `gp` - copy / paste from system clipboard
-- - `\` + key - toggle common options. Like `\h` toggles highlighting search.
-- - `<C-hjkl>` (four combos) - navigate between windows.
-- - `<M-hjkl>` in Insert/Command mode - navigate in that mode.
--
-- See also:
-- - `:h MiniBasics.config.options` - list of adjusted options
-- - `:h MiniBasics.config.mappings` - list of created mappings
-- - `:h MiniBasics.config.autocommands` - list of created autocommands
now(function()
  require("mini.basics").setup({
    -- Manage options in 'plugin/10_options.lua' for didactic purposes
    options = { basic = false },
    mappings = {
      -- Create `<C-hjkl>` mappings for window navigation
      windows = true,
      -- Create `<M-hjkl>` mappings for navigation in Insert and Command modes
      move_with_alt = true,
    },
  })
end)

-- Icon provider. Usually no need to use manually. It is used by plugins like
-- 'mini.pick', 'mini.files', 'mini.statusline', and others.
now(function()
  -- Set up to not prefer extension-based icon for some extensions
  local ext3_blocklist = { scm = true, txt = true, yml = true }
  local ext4_blocklist = { json = true, yaml = true }
  require("mini.icons").setup({
    use_file_extension = function(ext, _)
      return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
    end,
  })

  -- Mock 'nvim-tree/nvim-web-devicons' for plugins without 'mini.icons' support.
  -- Not needed for 'mini.nvim' or MiniMax, but might be useful for others.
  later(MiniIcons.mock_nvim_web_devicons)

  -- Add LSP kind icons. Useful for 'mini.completion'.
  later(MiniIcons.tweak_lsp_kind)
end)

-- Notifications provider. Shows all kinds of notifications in the upper right
-- corner (by default). Example usage:
-- - `:h vim.notify()` - show notification (hides automatically)
-- - `<Leader>en` - show notification history
--
-- See also:
-- - `:h MiniNotify.config` for some of common configuration examples.
now(function()
  require("mini.notify").setup({
    -- Don't show LSP progress popups (e.g. vtsls "Initializing 'tsconfig.json'
    -- (100%)" / "Analyzing 'Browser.ts'..."). Other notifications still show and
    -- everything remains in history (`<Leader>en`).
    lsp_progress = { enable = false },
    -- Show only the message, dropping the default `HH:MM:SS │ ` time prefix.
    content = {
      format = function(notif)
        return notif.msg
      end,
    },
    window = {
      winblend = 0, -- no dimming/blend over the wallpaper (default is 25)
      config = { title = "" }, -- drop the " Notifications " header; keep the border
    },
  })

  for _, g in ipairs({ "MiniNotifyNormal", "MiniNotifyBorder", "MiniNotifyLspProgress" }) do
    vim.api.nvim_set_hl(0, g, { fg = vim.api.nvim_get_hl(0, { name = g }).fg, bg = "NONE" })
  end
end)

-- Session management. A thin wrapper around `:h mksession` that consistently
-- manages session files. Example usage:
-- - `<Leader>sn` - start new session
-- - `<Leader>sr` - read previously started session
-- - `<Leader>sd` - delete previously started session
-- - `<Leader>ss` - restore the cwd's local session (LazyVim `<Space>qs` style)
now(function()
  require("mini.sessions").setup()

  -- The session is stored in the global sessions directory (`config.directory`,
  -- outside any project repo) under a filename derived from the cwd, rather than
  -- as a local 'Session.vim' inside the cwd. This keeps per-directory behavior
  -- without littering project repos (the cwd is often a git repo when editing).
  -- `Config.cwd_session_name()` is shared with the `<Leader>ss` mapping in
  -- 'plugin/20_keymaps.lua' so both sides agree on the file.
  --
  -- `MiniSessions.write`/`read` take a *name* (not a path) that is resolved
  -- relative to `config.directory` (see `:h MiniSessions.write()`), so this must
  -- be a single flat filename: encode the cwd and flatten path separators into
  -- '%' so each directory maps to a unique, slash-free name.
  Config.cwd_session_name = function()
    local enc = vim.uri_encode(vim.fn.getcwd(), "rfc3986"):gsub("/", "%%")
    return enc .. ".vim"
  end
  Config.cwd_session_path = function()
    return MiniSessions.config.directory .. "/" .. Config.cwd_session_name()
  end

  -- Read a session and re-trigger filetype detection on every loaded buffer.
  -- `mksession` (what 'mini.sessions' wraps) restores hidden buffers via `:badd`
  -- without firing `FileType`, so only the active window's buffer ends up with
  -- syntax highlighting; switching to any other restored buffer shows it plain.
  -- Re-running detection on all loaded, named, normal buffers sets 'filetype'
  -- (which fires the `FileType`/syntax machinery) so every buffer is highlighted
  -- regardless of when it's first viewed. Shared by the auto-restore below and
  -- the `<Leader>ss` mapping in 'plugin/20_keymaps.lua'.
  Config.restore_session = function(name)
    pcall(MiniSessions.read, name, { force = true })
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local normal = vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buftype == ""
        and vim.api.nvim_buf_get_name(buf) ~= ""
      if normal and vim.bo[buf].filetype == "" then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("filetype detect")
        end)
      end
    end
  end

  -- Skip auto-saving "trivial" sessions: when Neovim was opened on a single file
  -- (`nvim file`) or with no real (listed, named, non-special) buffers. This
  -- avoids creating sessions for one-off file edits.
  local should_autosave = function()
    -- Don't overwrite when explicitly started on a single file argument
    if vim.fn.argc(-1) == 1 then
      return false
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local listed = vim.bo[buf].buflisted and vim.bo[buf].buftype == ""
      if listed and vim.api.nvim_buf_get_name(buf) ~= "" then
        return true
      end
    end
    return false
  end

  Config.new_autocmd("VimLeavePre", "*", function()
    if not should_autosave() then
      return
    end
    -- `force = true` overwrites the existing session without prompting. The name
    -- resolves to the global sessions directory (keyed by cwd), so the file
    -- lands there rather than as a local 'Session.vim' in the repo.
    pcall(MiniSessions.write, Config.cwd_session_name(), { force = true })
  end, "Auto-save cwd session on exit")

  -- Auto-restore the cwd's session on startup, but only for a "bare" `nvim`:
  -- when no file arguments were passed (`nvim` with no `path/to/file`). Opening
  -- a specific file (`nvim file`) or piping stdin should not blow away that
  -- buffer with a restored session. If no session exists for the cwd, do
  -- nothing (no picker fallback) so a bare `nvim` just lands on `[No Name]`.
  Config.new_autocmd("VimEnter", "*", function()
    if vim.fn.argc(-1) > 0 then
      return
    end
    if vim.fn.filereadable(Config.cwd_session_path()) == 1 then
      Config.restore_session(Config.cwd_session_name())
    end
  end, "Auto-restore cwd session when started with no file args")
end)

-- Start screen ('mini.starter'). Disabled: plain `nvim` opens on an empty
-- `[No Name]` buffer (normal Vim behavior) instead of a splash screen.
-- Re-enable by uncommenting the block below (use `gcc`).
--
-- Example usage when enabled:
-- - Type prefix keys to limit available candidates
-- - Navigate down/up with `<C-n>` and `<C-p>`
-- - Press `<CR>` to select an entry
--
-- See also:
-- - `:h MiniStarter-example-config` - non-default config examples
-- - `:h MiniStarter-lifecycle` - how to work with Starter buffer
-- now(function()
--   require("mini.starter").setup()
-- end)

-- Statusline. Sets `:h 'statusline'` to show more info in a line below window.
-- Example usage:
-- - Left most section indicates current mode (text + highlighting).
-- - Second from left section shows "developer info": Git, diff, diagnostics, LSP.
-- - Center section shows the name of displayed buffer.
-- - Second to right section shows more buffer info.
-- - Right most section shows current cursor coordinates and search results.
--
-- See also:
-- - `:h MiniStatusline-example-content` - example of default content. Use it to
--   configure a custom statusline by setting `config.content.active` function.
-- now(function() require('mini.statusline').setup() end)

-- Renders dimmed (NonText) "file [flags] ──── line,col ──"; the middle `─` fill
-- comes from 'fillchars' stl:─ (set in 'plugin/10_options.lua'). The literal
-- "──" after `%l,%c` pins a short dash run on the right edge. See `:h 'statusline'`.
now(function()
  vim.o.statusline = "%<%#NonText#%f %h%m%r%= %l,%c ──"
end)

-- Tabline disabled. ('mini.tabline' is not set up.) Navigate buffers with
-- `[b` / `]b` or the buffer picker (`<Leader>fb`) instead of a visible tabline.
vim.o.showtabline = 0

-- Step one or two ============================================================
-- Load now if Neovim is started like `nvim -- path/to/file`, otherwise - later.
-- This ensures a correct behavior for files opened during startup.

-- Completion and signature help. Implements async "two stage" autocompletion:
-- - Based on attached LSP servers that support completion.
-- - Fallback (based on built-in keyword completion) if there is no LSP candidates.
--
-- Example usage in Insert mode with attached LSP:
-- - Start typing text that should be recognized by LSP (like variable name).
-- - After 100ms a popup menu with candidates appears.
-- - Press `<Tab>` / `<S-Tab>` to navigate down/up the list. These are set up
--   in 'mini.keymap'. You can also use `<C-n>` / `<C-p>`.
-- - During navigation there is an info window to the right showing extra info
--   that the LSP server can provide about the candidate. It appears after the
--   candidate stays selected for 100ms. Use `<C-f>` / `<C-b>` to scroll it.
-- - Navigating to an entry also changes buffer text. If you are happy with it,
--   keep typing after it. To discard completion completely, press `<C-e>`.
-- - After pressing special trigger(s), usually `(`, a window appears that shows
--   the signature of the current function/method. It gets updated as you type
--   showing the currently active parameter.
--
-- Example usage in Insert mode without an attached LSP or in places not
-- supported by the LSP (like comments):
-- - Start typing a word that is present in current or opened buffers.
-- - After 100ms popup menu with candidates appears.
-- - Navigate with `<Tab>` / `<S-Tab>` or `<C-n>` / `<C-p>`. This also updates
--   buffer text. If happy with choice, keep typing. Stop with `<C-e>`.
--
-- It also works with snippet candidates provided by LSP server. Best experience
-- when paired with 'mini.snippets' (which is set up in this file).
now_if_args(function()
  -- A custom filter+sort that replaces the built-in 'fuzzy'/'prefix' methods
  -- (which lean on `matchfuzzy()` and have weak scoring). It scores each item
  -- with 'mini.fuzzy' (rewards contiguous + early matches) and layers on the
  -- ranking bonuses blink.cmp gave us in '~/dotfiles/nvim':
  --   - exact match (case-sensitive) > prefix match > case match > fuzzy only
  --   - shorter labels win ties (less "scope creep" in the menu)
  --   - LSP `sortText` is the final, stable tiebreak (servers use it to express
  --     intent, e.g. ordering by relevance / recency)
  -- Lower combined score = better; we sort ascending.
  local fuzzy = require("mini.fuzzy")
  local filterword = function(item)
    return item.filterText or item.label or ""
  end

  local mini_completion_filtersort = function(items, base)
    -- Empty query: keep server order (don't fuzzy-rank nothing).
    if base == "" then
      return vim.deepcopy(items)
    end

    local base_lower = base:lower()
    local scored = {}
    for original_index, item in ipairs(items) do
      local word = filterword(item)
      local m = fuzzy.match(base, word)
      -- `score < 0` means no fuzzy match at all -> filter the item out.
      if m.score >= 0 then
        local word_lower = word:lower()
        -- Bonuses are subtracted so a better match yields a smaller score.
        -- Tiers are spaced far apart so a higher tier always beats a lower one
        -- regardless of the raw fuzzy score (which is bounded by cutoff^2).
        local bonus = 0
        if word == base then
          bonus = bonus + 30000 -- exact, case-sensitive
        elseif word_lower == base_lower then
          bonus = bonus + 20000 -- exact, case-insensitive
        elseif vim.startswith(word_lower, base_lower) then
          bonus = bonus + 10000 -- prefix
          if vim.startswith(word, base) then
            bonus = bonus + 2000 -- case-correct prefix
          end
        end
        scored[#scored + 1] = {
          item = item,
          original_index = original_index,
          score = m.score - bonus,
          word_len = #word,
          sort_text = item.sortText or item.label or "",
        }
      end
    end

    table.sort(scored, function(a, b)
      if a.score ~= b.score then
        return a.score < b.score
      end
      if a.word_len ~= b.word_len then
        return a.word_len < b.word_len
      end
      if a.sort_text ~= b.sort_text then
        return a.sort_text < b.sort_text
      end
      return a.original_index < b.original_index
    end)

    return vim.tbl_map(function(x)
      return x.item
    end, scored)
  end

  -- Post-processing of LSP responses.
  -- Drop noisy 'Text'/'Keyword' suggestions
  -- (negative priority removes them) and show snippets last.
  local process_items_opts = {
    filtersort = mini_completion_filtersort,
    kind_priority = { Text = -1, Keyword = -1, Snippet = 99 },
  }
  -- Merge in namespace-import candidates for capitalized typescript project files
  local process_items = function(items, base)
    local ok, extra = pcall(function()
      return require("ts_imports").candidates(base)
    end)
    if ok and type(extra) == "table" and #extra > 0 then
      -- Drop any synthetic item that collides with LSP item. server wins.
      local seen = {}
      for _, item in ipairs(items) do
        seen[item.label] = true
      end
      for _, item in ipairs(extra) do
        if not seen[item.label] then
          items[#items + 1] = item
        end
      end
    end
    return MiniCompletion.default_process_items(items, base, process_items_opts)
  end
  require("mini.completion").setup({
    lsp_completion = {
      -- Without this config autocompletion is set up through `:h 'completefunc'`.
      -- Although not needed, setting up through `:h 'omnifunc'` is cleaner
      -- (sets up only when needed) and makes it possible to use `<C-u>`.
      source_func = "omnifunc",
      auto_setup = false,
      process_items = process_items,
    },
  })

  -- Set 'omnifunc' for LSP completion only when needed.
  local on_attach = function(ev)
    vim.bo[ev.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
  end
  Config.new_autocmd("LspAttach", nil, on_attach, "Set 'omnifunc'")

  -- Advertise to servers that Neovim now supports certain set of completion and
  -- signature features through 'mini.completion'.
  vim.lsp.config("*", { capabilities = MiniCompletion.get_lsp_capabilities() })

  -- Disable autocompletion in filetypes where a popup is unwanted (prose / commit
  -- messages). Mirrors the blink.cmp `enabled` list in '~/dotfiles/nvim'.
  -- Uses the per-buffer `vim.b.minicompletion_disable` flag (the same mechanism
  -- 'mini.completion' uses itself for 'TelescopePrompt'). Built-in `<C-x>...`
  -- completion still works manually.
  local no_complete_ft = { "text", "gitcommit" }
  Config.new_autocmd("FileType", no_complete_ft, function()
    vim.b.minicompletion_disable = true
  end, "Disable autocompletion")
end)

-- Navigate and manipulate file system
--
-- Navigation is done using column view (Miller columns) to display nested
-- directories, they are displayed in floating windows in top left corner.
--
-- Manipulate files and directories by editing text as regular buffers.
--
-- Example usage:
-- - `<Leader>ed` - open current working directory
-- - `<Leader>ef` - open directory of current file (needs to be present on disk)
--
-- Basic navigation:
-- - `l` - go in entry at cursor: navigate into directory or open file
-- - `h` - go out of focused directory
-- - Navigate window as any regular buffer
-- - Press `g?` inside explorer to see more mappings
--
-- Basic manipulation:
-- - After any following action, press `=` in Normal mode to synchronize, read
--   carefully about actions, press `y` or `<CR>` to confirm
-- - New entry: press `o` and type its name; end with `/` to create directory
-- - Rename: press `C` and type new name
-- - Delete: type `dd`
-- - Move/copy: type `dd`/`yy`, navigate to target directory, press `p`
--
-- See also:
-- - `:h MiniFiles-navigation` - more details about how to navigate
-- - `:h MiniFiles-manipulation` - more details about how to manipulate
-- - `:h MiniFiles-examples` - examples of common setups
now_if_args(function()
  -- Enable directory/file preview
  require("mini.files").setup({ windows = { preview = true } })

  -- Add common bookmarks for every explorer. Example usage inside explorer:
  -- - `'c` to navigate into your config directory
  -- - `g?` to see available bookmarks
  local add_marks = function()
    MiniFiles.set_bookmark("c", vim.fn.stdpath("config"), { desc = "Config" })
    local minideps_plugins = vim.fn.stdpath("data") .. "/site/pack/deps/opt"
    MiniFiles.set_bookmark("p", minideps_plugins, { desc = "Plugins" })
    MiniFiles.set_bookmark("w", vim.fn.getcwd, { desc = "Working directory" })
  end
  Config.new_autocmd("User", "MiniFilesExplorerOpen", add_marks, "Add bookmarks")
end)

-- Miscellaneous small but useful functions. Example usage:
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
-- - `<Leader>or` - resize window to its "editable width"
-- - `:lua put_text(vim.lsp.get_clients())` - put output of a function below
--   cursor in current buffer. Useful for a detailed exploration.
-- - `:lua put(MiniMisc.stat_summary(MiniMisc.bench_time(f, 100)))` - run
--   function `f` 100 times and report statistical summary of execution times
now_if_args(function()
  -- Makes `:h MiniMisc.put()` and `:h MiniMisc.put_text()` public
  require("mini.misc").setup()

  -- Change current working directory based on the current file path. It
  -- searches up the file tree until the first root marker ('.git' or 'Makefile')
  -- and sets their parent directory as a current directory.
  -- This is helpful when simultaneously dealing with files from several projects.
  MiniMisc.setup_auto_root()

  -- Restore latest cursor position on file open
  MiniMisc.setup_restore_cursor()

  -- Synchronize terminal emulator background with Neovim's background to remove
  -- possibly different color padding around Neovim instance
  MiniMisc.setup_termbg_sync()
end)

-- Step two ===================================================================

-- Extra 'mini.nvim' functionality.
--
-- See also:
-- - `:h MiniExtra.pickers` - pickers. Most are mapped in `<Leader>f` group.
--   Calling `setup()` makes 'mini.pick' respect 'mini.extra' pickers.
-- - `:h MiniExtra.gen_ai_spec` - 'mini.ai' textobject specifications
-- - `:h MiniExtra.gen_highlighter` - 'mini.hipatterns' highlighters
later(function()
  require("mini.extra").setup()
end)

-- Extend and create a/i textobjects, like `:h a(`, `:h a'`, and more).
-- Contains not only `a` and `i` type of textobjects, but also their "next" and
-- "last" variants that will explicitly search for textobjects after and before
-- cursor. Example usage:
-- - `ci)` - *c*hange *i*inside parenthesis (`)`)
-- - `di(` - *d*elete *i*inside padded parenthesis (`(`)
-- - `yaq` - *y*ank *a*round *q*uote (any of "", '', or ``)
-- - `vif` - *v*isually select *i*inside *f*unction call
-- - `cina` - *c*hange *i*nside *n*ext *a*rgument
-- - `valaala` - *v*isually select *a*round *l*ast (i.e. previous) *a*rgument
--   and then again reselect *a*round new *l*ast *a*rgument
--
-- See also:
-- - `:h text-objects` - general info about what textobjects are
-- - `:h MiniAi-builtin-textobjects` - list of all supported textobjects
-- - `:h MiniAi-textobject-specification` - examples of custom textobjects
later(function()
  local ai = require("mini.ai")
  ai.setup({
    -- 'mini.ai' can be extended with custom textobjects
    custom_textobjects = {
      -- Make `aB` / `iB` act on around/inside whole *b*uffer
      B = MiniExtra.gen_ai_spec.buffer(),
      -- For more complicated textobjects that require structural awareness,
      -- use tree-sitter. This example makes `aF`/`iF` mean around/inside function
      -- definition (not call). See `:h MiniAi.gen_spec.treesitter()` for details.
      F = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
    },

    -- 'mini.ai' by default mostly mimics built-in search behavior: first try
    -- to find textobject covering cursor, then try to find to the right.
    -- Although this works in most cases, some are confusing. It is more robust to
    -- always try to search only covering textobject and explicitly ask to search
    -- for next (`an`/`in`) or last (`al`/`il`).
    -- Try this. If you don't like it - delete next line and this comment.
    search_method = "cover",
  })
end)

-- Align text interactively. Example usage:
-- - `gaip,` - `ga` (align operator) *i*nside *p*aragraph by comma
-- - `gAip` - start interactive alignment on the paragraph. Choose how to
--   split, justify, and merge string parts. Press `<CR>` to make it permanent,
--   press `<Esc>` to go back to initial state.
--
-- See also:
-- - `:h MiniAlign-example` - hands-on list of examples to practice aligning
-- - `:h MiniAlign.gen_step` - list of support step customizations
-- - `:h MiniAlign-algorithm` - how alignment is done on algorithmic level
later(function()
  require("mini.align").setup()
end)

-- Go forward/backward with square brackets. Implements consistent sets of mappings
-- for selected targets (like buffers, diagnostic, quickfix list entries, etc.).
-- Example usage:
-- - `]b` - go to next buffer
-- - `[j` - go to previous jump inside current buffer
-- - `[Q` - go to first entry of quickfix list
-- - `]X` - go to last conflict marker in a buffer
--
-- See also:
-- - `:h MiniBracketed` - overall mapping design and list of targets
later(function()
  require("mini.bracketed").setup()
end)

-- Remove buffers. Opened files occupy space in tabline and buffer picker.
-- When not needed, they can be removed. Example usage:
-- - `<Leader>bw` - completely wipeout current buffer (see `:h :bwipeout`)
-- - `<Leader>bW` - completely wipeout current buffer even if it has changes
-- - `<Leader>bd` - delete current buffer (see `:h :bdelete`)
later(function()
  require("mini.bufremove").setup()
end)

-- Show next key clues in a bottom right window. Requires explicit opt-in for
-- keys that act as clue trigger. Example usage:
-- - Press `<Leader>` and wait for 1 second. A window with information about
--   next available keys should appear.
-- - Press one of the listed keys. Window updates immediately to show information
--   about new next available keys. You can press `<BS>` to go back in key sequence.
-- - Press keys until they resolve into some mapping.
--
-- Note: it is designed to work in buffers for normal files. It doesn't work in
-- special buffers (like for 'mini.starter' or 'mini.files') to not conflict
-- with its local mappings.
--
-- See also:
-- - `:h MiniClue-examples` - examples of common setups
-- - `:h MiniClue.ensure_buf_triggers()` - use it to enable triggers in buffer
-- - `:h MiniClue.set_mapping_desc()` - change mapping description not from config
later(function()
  local miniclue = require("mini.clue")
  -- stylua: ignore
  miniclue.setup({
    -- Define which clues to show. By default shows only clues for custom mappings
    -- (uses `desc` field from the mapping; takes precedence over custom clue).
    clues = {
      -- This is defined in 'plugin/20_keymaps.lua' with Leader group descriptions
      Config.leader_group_clues,
      -- Bare `f` "Find" prefix (mappings in 'plugin/20_keymaps.lua').
      { mode = 'n', keys = 'f', desc = '+Find' },
      miniclue.gen_clues.builtin_completion(),
      miniclue.gen_clues.g(),
      miniclue.gen_clues.marks(),
      miniclue.gen_clues.registers(),
      miniclue.gen_clues.square_brackets(),
      -- This creates a submode for window resize mappings. Try the following:
      -- - Press `<C-w>s` to make a window split.
      -- - Press `<C-w>+` to increase height. Clue window still shows clues as if
      --   `<C-w>` is pressed again. Keep pressing just `+` to increase height.
      --   Try pressing `-` to decrease height.
      -- - Stop submode either by `<Esc>` or by any key that is not in submode.
      miniclue.gen_clues.windows({ submode_resize = true }),
      miniclue.gen_clues.z(),
    },
    -- Show the clue window sooner (default is 1000ms).
    window = { delay = 200 },
    -- Explicitly opt-in for set of common keys to trigger clue window
    triggers = {
      { mode = { 'n', 'x' }, keys = '<Leader>' }, -- Leader triggers
      { mode =   'n',        keys = '\\' },       -- mini.basics
      { mode = { 'n', 'x' }, keys = '[' },        -- mini.bracketed
      { mode = { 'n', 'x' }, keys = ']' },
      { mode =   'i',        keys = '<C-x>' },    -- Built-in completion
      { mode = { 'n', 'x' }, keys = 'g' },        -- `g` key
      { mode =   'n',        keys = 'f' },        -- `f` Find prefix (mini.pick)
      { mode = { 'n', 'x' }, keys = "'" },        -- Marks
      { mode = { 'n', 'x' }, keys = '`' },
      { mode = { 'n', 'x' }, keys = '"' },        -- Registers
      { mode = { 'i', 'c' }, keys = '<C-r>' },
      { mode =   'n',        keys = '<C-w>' },    -- Window commands
      { mode = { 'n', 'x' }, keys = 's' },        -- `s` key (flash.nvim jump)
      { mode = { 'n', 'x' }, keys = 'z' },        -- `z` key
    },
  })
end)

-- Command line tweaks. Improves command line editing with:
-- - Autocompletion. Basically an automated `:h cmdline-completion`.
-- - Autocorrection of words as-you-type. Like `:W`->`:w`, `:lau`->`:lua`, etc.
-- - Autopeek command range (like line number at the start) as-you-type.
later(function()
  require("mini.cmdline").setup()
end)

-- Tweak and save any color scheme. Contains utility functions to work with
-- color spaces and color schemes. Example usage:
-- - `:Colorscheme default` - switch with animation to the default color scheme
--
-- See also:
-- - `:h MiniColors.interactive()` - interactively tweak color scheme
-- - `:h MiniColors-recipes` - common recipes to use during interactive tweaking
-- - `:h MiniColors.convert()` - convert between color spaces
-- - `:h MiniColors-color-spaces` - list of supported color sapces
--
-- It is not enabled by default because it is not really needed on a daily basis.
-- Uncomment next line (use `gcc`) to enable.
-- later(function() require('mini.colors').setup() end)

-- Comment lines. Provides functionality to work with commented lines.
-- Uses `:h 'commentstring'` option to infer comment structure.
-- Example usage:
-- - `gcip` - toggle comment (`gc`) *i*inside *p*aragraph
-- - `vapgc` - *v*isually select *a*round *p*aragraph and toggle comment (`gc`)
-- - `gcgc` - uncomment (`gc`, operator) comment block at cursor (`gc`, textobject)
--
-- The built-in `:h commenting` is based on 'mini.comment'. Yet this module is
-- still enabled as it provides more customization opportunities.
later(function()
  require("mini.comment").setup()
end)

-- Autohighlight word under cursor with a customizable delay.
-- Word boundaries are defined based on `:h 'iskeyword'` option.
--
-- It is not enabled by default because its effects are a matter of taste.
-- Uncomment next line (use `gcc`) to enable.
-- later(function() require('mini.cursorword').setup() end)

-- Work with diff hunks that represent the difference between the buffer text and
-- some reference text set by a source. Default source uses text from Git index.
-- Also provides summary info used in developer section of 'mini.statusline'.
-- Example usage:
-- - `ghip` - apply hunks (`gh`) within *i*nside *p*aragraph
-- - `gHG` - reset hunks (`gH`) from cursor until end of buffer (`G`)
-- - `ghgh` - apply (`gh`) hunk at cursor (`gh`)
-- - `gHgh` - reset (`gH`) hunk at cursor (`gh`)
-- - `<Leader>go` - toggle overlay
--
-- See also:
-- - `:h MiniDiff-overview` - overview of how module works
-- - `:h MiniDiff-diff-summary` - available summary information
-- - `:h MiniDiff.gen_source` - available built-in sources
later(function()
  require("mini.diff").setup()
end)

-- Git integration for more straightforward Git actions based on Neovim's state.
-- It is not meant as a fully featured Git client, only to provide helpers that
-- integrate better with Neovim. Example usage:
-- - `<Leader>gs` - show information at cursor
-- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- - `<Leader>gL` - show Git log of current file
-- - `:Git help git` - show output of `git help git` inside Neovim
--
-- See also:
-- - `:h MiniGit-examples` - examples of common setups
-- - `:h :Git` - more details about `:Git` user command
-- - `:h MiniGit.show_at_cursor()` - what information at cursor is shown
later(function()
  require("mini.git").setup()
end)

-- Highlight patterns in text. Like `TODO`/`NOTE` or color hex codes.
-- Example usage:
-- - `:Pick hipatterns` - pick among all highlighted patterns
--
-- See also:
-- - `:h MiniHipatterns-examples` - examples of common setups
later(function()
  local hipatterns = require("mini.hipatterns")
  local hi_words = MiniExtra.gen_highlighter.words
  hipatterns.setup({
    highlighters = {
      -- Highlight a fixed set of common words. Will be highlighted in any place,
      -- not like "only in comments".
      fixme = hi_words({ "FIXME", "Fixme", "fixme" }, "MiniHipatternsFixme"),
      hack = hi_words({ "HACK", "Hack", "hack" }, "MiniHipatternsHack"),
      todo = hi_words({ "TODO", "Todo", "todo" }, "MiniHipatternsTodo"),
      note = hi_words({ "NOTE", "Note", "note" }, "MiniHipatternsNote"),

      -- Highlight hex color string (#aabbcc) with that color as a background
      hex_color = hipatterns.gen_highlighter.hex_color(),
    },
  })
end)

-- Visualize and work with indent scope. It visualizes indent scope "at cursor"
-- with animated vertical line. Provides relevant motions and textobjects.
-- Example usage:
-- - `cii` - *c*hange *i*nside *i*ndent scope
-- - `Vaiai` - *V*isually select *a*round *i*ndent scope and then again
--   reselect *a*round new *i*indent scope
-- - `[i` / `]i` - navigate to scope's top / bottom
--
-- See also:
-- - `:h MiniIndentscope.gen_animation` - available animation rules
-- Disabled: no indent-scope guide line. Uncomment to re-enable.
-- later(function()
-- 	require("mini.indentscope").setup()
-- end)

-- Jump to next/previous single character. It implements "smarter `fFtT` keys"
-- (see `:h f`) that work across multiple lines, start "jumping mode", and
-- highlight all target matches. Example usage:
-- - `Fx` - move backward onto previous character "x"
-- - `dt)` - *d*elete *t*ill next closing parenthesis (`)`)
--
-- NOTE: the forward `f` mapping is DISABLED so that `f` is a finder prefix
-- (`ff`/`fr`/`fo`/`fl`, see 'plugin/20_keymaps.lua'), mirroring '~/dotfiles/nvim'.
-- `F` (backward), `t`/`T` (till), and `;` (repeat) remain mini.jump motions.
later(function()
  require("mini.jump").setup({
    mappings = { forward = "" },
  })
end)

-- Special key mappings. Provides helpers to map:
-- - Multi-step actions. Apply action 1 if condition is met; else apply
--   action 2 if condition is met; etc.
-- - Combos. Sequence of keys where each acts immediately plus execute extra
--   action if all are typed fast enough. Useful for Insert mode mappings to not
--   introduce delay when typing mapping keys without intention to execute action.
--
-- See also:
-- - `:h MiniKeymap-examples` - examples of common setups
-- - `:h MiniKeymap.map_multistep()` - map multi-step action
-- - `:h MiniKeymap.map_combo()` - map combo
later(function()
  require("mini.keymap").setup()
  -- Navigate 'mini.completion' menu with `<Tab>` /  `<S-Tab>`
  MiniKeymap.map_multistep("i", "<Tab>", { "pmenu_next" })
  MiniKeymap.map_multistep("i", "<S-Tab>", { "pmenu_prev" })
  MiniKeymap.map_multistep("i", "<C-j>", { "pmenu_next" })
  MiniKeymap.map_multistep("i", "<C-k>", { "pmenu_prev" })
  local show_completion = {
    condition = function()
      return true
    end,
    action = function()
      MiniCompletion.complete_twostage()
      return ""
    end,
  }
  MiniKeymap.map_multistep("i", "<C-l>", { "pmenu_accept", show_completion })

  MiniKeymap.map_multistep("i", "<CR>", { "pmenu_accept", "minipairs_cr" })
  MiniKeymap.map_multistep("i", "<BS>", { "minipairs_bs" })
end)

-- Window with text overview. It is displayed on the right hand side. Can be used
-- for quick overview and navigation. Hidden by default. Example usage:
-- - `<Leader>mt` - toggle map window
-- - `<Leader>mf` - focus on the map for fast navigation
-- - `<Leader>ms` - change map's side (if it covers something underneath)
--
-- See also:
-- - `:h MiniMap.gen_encode_symbols` - list of symbols to use for text encoding
-- - `:h MiniMap.gen_integration` - list of integrations to show in the map
--
-- NOTE: Might introduce lag on very big buffers (10000+ lines)
later(function()
  local map = require("mini.map")
  map.setup({
    -- Use Braille dots to encode text
    symbols = { encode = map.gen_encode_symbols.dot("4x2") },
    -- Show built-in search matches, 'mini.diff' hunks, and diagnostic entries
    integrations = {
      map.gen_integration.builtin_search(),
      map.gen_integration.diff(),
      map.gen_integration.diagnostic(),
    },
  })

  -- Map built-in navigation characters to force map refresh
  for _, key in ipairs({ "n", "N", "*", "#" }) do
    local rhs = key
      -- Also open enough folds when jumping to the next match
      .. "zv"
      .. "<Cmd>lua MiniMap.refresh({}, { lines = false, scrollbar = false })<CR>"
    vim.keymap.set("n", key, rhs)
  end
end)

-- Move any selection in any direction. Example usage in Normal mode:
-- - `<M-j>`/`<M-k>` - move current line down / up
-- - `<M-h>`/`<M-l>` - decrease / increase indent of current line
--
-- Example usage in Visual mode:
-- - `<M-h>`/`<M-j>`/`<M-k>`/`<M-l>` - move selection left/down/up/right
later(function()
  require("mini.move").setup()
end)

-- Autopairs functionality. Insert pair when typing opening character and go over
-- right character if it is already to cursor's right. Also provides mappings for
-- `<CR>` and `<BS>` to perform extra actions when inside pair.
-- Example usage in Insert mode:
-- - `(` - insert "()" and put cursor between them
-- - `)` when there is ")" to the right - jump over ")" without inserting new one
-- - `<C-v>(` - always insert a single "(" literally. This is useful since
--   'mini.pairs' doesn't provide particularly smart behavior, like auto balancing
later(function()
  -- Create pairs not only in Insert, but also in Command line mode
  require("mini.pairs").setup({ modes = { command = true } })
end)

-- Pick anything with single window layout and fast matching. This is one of
-- the main usability improvements as it powers a lot of "find things quickly"
-- workflows. How to use a picker:
-- - Start picker, usually with `:Pick <picker-name>` command. Like `:Pick files`.
--   It shows a single window in the bottom left corner filled with possible items
--   to choose from. Current item has special full line highlighting.
--   At the top there is a current query used to filter+sort items.
-- - Type characters (appear at top) to narrow down items. There is fuzzy matching:
--   characters may not match one-by-one, but they should be in correct order.
-- - Navigate down/up with `<C-n>`/`<C-p>`.
-- - Press `<Tab>` to show item's preview. `<Tab>` again goes back to items.
-- - Press `<S-Tab>` to show picker's info. `<S-Tab>` again goes back to items.
-- - Press `<CR>` to choose an item. The exact action depends on the picker: `files`
--   picker opens a selected file, `help` picker opens help page on selected tag.
--   To close picker without choosing an item, press `<Esc>`.
--
-- Example usage:
-- - `<Leader>ff` - *f*ind *f*iles; for best performance requires `ripgrep`
-- - `<Leader>fg` - *f*ind inside files (a.k.a. "to *g*rep"); requires `ripgrep`
-- - `<Leader>fh` - *f*ind *h*elp tag
-- - `<Leader>fr` - *r*esume latest picker
-- - `:h vim.ui.select()` - implemented with 'mini.pick'
--
-- See also:
-- - `:h MiniPick-overview` - overview of picker functionality
-- - `:h MiniPick-examples` - examples of common setups
-- - `:h MiniPick.builtin` and `:h MiniExtra.pickers` - available pickers;
--   Execute one either with Lua function, `:Pick <picker-name>` command, or
--   one of `<Leader>f` mappings defined in 'plugin/20_keymaps.lua'
later(function()
  -- Centered floating window (~78% x ~70%) instead of mini.pick's default
  -- bottom-left strip. Computed from `vim.o` on every open so it tracks
  -- terminal resizes (config is a callable, re-run each `MiniPick.start`).
  local function win_config()
    local height = math.floor(0.7 * vim.o.lines)
    local width = math.floor(0.78 * vim.o.columns)
    return {
      anchor = "NW",
      height = height,
      width = width,
      row = math.floor(0.5 * (vim.o.lines - height)),
      col = math.floor(0.5 * (vim.o.columns - width)),
      border = "rounded",
    }
  end

  -- Custom item display for the position pickers (grep, lsp references/symbols,
  -- buffer lines): mini.extra encodes those items' text as `path│lnum│col│ body`
  -- (the `│` are literal `\0` separators rendered by `default_show`). That puts
  -- two noisy numeric columns between the path and the matched line.
  --
  -- This rewrites each visible item's text to `path:lnum` + padding + body, so:
  -- - the column number is dropped from the display (jumping still uses the
  --   item's real `.lnum`/`.col` table fields, which are untouched), and
  -- - `path:lnum` is right-padded to a common width so every body starts in the
  --   same column (alignment is computed per frame over the visible items).
  -- Setting a global `source.show` makes mini.extra/builtin pickers stop
  -- defaulting to their icon-showing renderer (they do `config.source.show or
  -- show_with_icons`), so re-enable icons here to keep devicons on files,
  -- buffers, grep, etc. `opts` from a builtin is merged on top so an explicit
  -- per-picker `show_icons` still wins.
  local pick = require("mini.pick")

  -- `default_show` only highlights the single match span the sorter picked per
  -- item, which for these reformatted lines lands on the first occurrence —
  -- usually inside the path (e.g. `core/Activity.ts`), never the body. This
  -- adds extmarks for EVERY occurrence of the typed query in each visible line
  -- (path and body alike), so all matches light up. Purely additive: it touches
  -- only highlights, never matching/sorting, so streaming results are unaffected.
  local ranges_ns = vim.api.nvim_create_namespace("MiniPickRanges")
  local function highlight_all_occurrences(buf_id, query)
    -- `query` is an array of typed chars/tokens; the contiguous typed string is
    -- what grep/grep_live search for. Highlight it as a plain (case-insensitive
    -- when 'ignorecase') substring — matches the grep feel and covers all hits.
    local needle = table.concat(query or {})
    if needle == "" then
      return
    end
    local ignorecase = vim.o.ignorecase and not (vim.o.smartcase and needle:find("%u"))
    local hay_needle = ignorecase and needle:lower() or needle
    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    local opts = { hl_group = "MiniPickMatchRanges", hl_mode = "combine", priority = 201 }
    for row, line in ipairs(lines) do
      local hay = ignorecase and line:lower() or line
      local from = 1
      while true do
        -- Plain find (4th arg true) so regex specials in the query are literal.
        local s, e = hay:find(hay_needle, from, true)
        if not s then
          break
        end
        opts.end_row, opts.end_col = row - 1, e
        pcall(vim.api.nvim_buf_set_extmark, buf_id, ranges_ns, row - 1, s - 1, opts)
        from = e + 1
      end
    end
  end

  local function show_aligned(buf_id, items, query, opts)
    opts = vim.tbl_extend("keep", opts or {}, { show_icons = true })
    -- Split each item into a `path:lnum` head and a body. Two source formats
    -- carry a `path SEP lnum SEP col SEP body` shape:
    --   - grep (ripgrep `--field-match-separator \x00`): `\0`-separated, which
    --     `default_show` renders as `│`. The raw item text still has `\0`.
    --   - LSP references/symbols (mini.extra): literal `│` separators in text.
    -- Both are reformatted to `path:lnum` + padding + body. Everything else
    -- (files, help, buffers, ...) doesn't match and is passed through.
    local BAR = "│" -- U+2502, the literal separator mini.extra writes (3 bytes)
    local parsed = {}
    local head_width = 0
    for i, item in ipairs(items) do
      local text = type(item) == "table" and item.text or item
      local head, body
      if type(text) == "string" then
        -- Try `\0`-separated (grep) first, then literal `│` (LSP). `col` is
        -- matched and dropped; `rest` keeps the body, sans leading separator.
        local path, lnum, rest = text:match("^(.-)%z(%d+)%z%d+%z?(.*)$")
        if not path then
          path, lnum, rest = text:match("^(.-)" .. BAR .. "(%d+)" .. BAR .. "%d+" .. BAR .. "?(.*)$")
        end
        if path then
          head = path .. ":" .. lnum
          -- The matched separator before the body is already consumed above;
          -- just trim leading whitespace (LSP bodies start with a space).
          body = (rest:gsub("^%s+", ""))
        end
      end
      parsed[i] = body and { head = head, body = body } or nil
      if body then
        head_width = math.max(head_width, vim.fn.strchars(head))
      end
    end

    -- If nothing parsed (non-position picker), render with the default and add
    -- the all-occurrences highlight on top.
    if head_width == 0 then
      pick.default_show(buf_id, items, query, opts)
      return highlight_all_occurrences(buf_id, query)
    end

    -- Rebuild a shallow-copied item list with reformatted text. Copy so the
    -- picker's own items (and their `.lnum`/`.col`) are never mutated.
    local shown = {}
    for i, item in ipairs(items) do
      local p = parsed[i]
      if p then
        local pad = string.rep(" ", head_width - vim.fn.strchars(p.head) + 2)
        local text = p.head .. pad .. p.body
        shown[i] = type(item) == "table" and vim.tbl_extend("force", item, { text = text }) or text
      else
        shown[i] = item
      end
    end

    pick.default_show(buf_id, shown, query, opts)
    return highlight_all_occurrences(buf_id, query)
  end

  -- Custom matcher (filter+sort) that delegates to the `fzf` binary so the
  -- in-memory pickers (files, buffers, oldfiles, document_symbol, references,
  -- buf_lines, ...) rank with fzf's algorithm instead of mini's built-in fuzzy
  -- scorer
  local has_fzf = vim.fn.executable("fzf") == 1
  local fzf_match = function(stritems, inds, query)
    -- Empty query: keep current order (mirrors default_match's fast path).
    if #query == 0 then
      return vim.deepcopy(inds)
    end

    -- Map each stritem back to its index. Items can repeat (e.g. duplicate
    -- buffer lines), so keep a stack of indices per text and pop in fzf's
    -- returned order, preserving fzf's ranking for distinct lines.
    local by_text = {}
    local input = {}
    for _, ind in ipairs(inds) do
      local text = stritems[ind]
      local bucket = by_text[text]
      if bucket == nil then
        bucket = {}
        by_text[text] = bucket
      end
      bucket[#bucket + 1] = ind
      input[#input + 1] = text
    end

    -- `--filter` runs fzf non-interactively: read stdin, print matching lines
    -- in score order. `--no-sort` would keep input order, so we omit it.
    local needle = table.concat(query)
    local out = vim.fn.systemlist({ "fzf", "--filter=" .. needle }, input)
    if vim.v.shell_error ~= 0 and #out == 0 then
      -- No matches (fzf exits 1) -> empty result
      return {}
    end

    local result = {}
    for _, line in ipairs(out) do
      local bucket = by_text[line]
      if bucket and #bucket > 0 then
        result[#result + 1] = table.remove(bucket, 1)
      end
    end
    return result
  end

  -- Wrap with the async contract MiniPick expects when a picker is active:
  -- return synchronously when possible, else hand results to
  -- `set_picker_match_inds`. Falls back to `default_match` without fzf.
  local mini_match = function(stritems, inds, query, opts)
    if not has_fzf then
      return MiniPick.default_match(stritems, inds, query, opts)
    end
    opts = opts or {}
    local is_sync = opts.sync or not MiniPick.is_picker_active()
    local ok, res = pcall(fzf_match, stritems, inds, query)
    if not ok then
      -- Any unexpected error: degrade to the built-in matcher.
      return MiniPick.default_match(stritems, inds, query, opts)
    end
    if is_sync then
      return res
    end
    return MiniPick.set_picker_match_inds(res)
  end

  pick.setup({
    source = {
      -- Applies to every picker; `show_aligned` only reformats position items
      -- and passes everything else through to `default_show`.
      show = show_aligned,
      -- fzf-backed ranking for in-memory pickers; falls back to built-in.
      match = mini_match,
    },
    window = {
      config = win_config,
      -- Prettier prompt: nerd-font glyphs for the prefix and caret.
      prompt_prefix = "  ",
      prompt_caret = "▏",
    },
  })

  -- Theming. `25_colorscheme.lua` loads first (alphabetical) and has already
  -- applied base16 + transparency, so pull live accent colors from existing
  -- groups rather than hardcoding hexes — this follows any palette swap.
  local set_hl = vim.api.nvim_set_hl
  local function fg_of(name)
    return vim.api.nvim_get_hl(0, { name = name }).fg
  end
  local accent = fg_of("Function") -- blue   (base0D) — framing/border color
  local query = fg_of("Type") -- yellow (base0A) — search/query accent
  local busy = fg_of("Statement") -- red    (base08) — "processing" feedback
  local sel_bg = vim.api.nvim_get_hl(0, { name = "Visual" }).bg -- base02 selection

  -- Keep the picker body transparent (consistent with the rest of the config),
  -- only coloring the bits that give the window structure.
  for _, g in ipairs({
    "MiniPickNormal",
    "MiniPickPromptCaret",
    "MiniPickHeader",
  }) do
    set_hl(0, g, { fg = fg_of(g), bg = "NONE" })
  end

  -- Visible accent border + border text (query/source name live on the border).
  set_hl(0, "MiniPickBorder", { fg = accent, bg = "NONE" })
  set_hl(0, "MiniPickBorderText", { fg = query, bg = "NONE", bold = true })
  set_hl(0, "MiniPickBorderBusy", { fg = busy, bg = "NONE" })

  -- Prompt + caret: query in yellow so the typed text reads apart from the
  -- blue border, prefix glyph in the framing color.
  set_hl(0, "MiniPickPrompt", { fg = query, bg = "NONE", bold = true })
  set_hl(0, "MiniPickPromptPrefix", { fg = accent, bg = "NONE", bold = true })
  set_hl(0, "MiniPickPromptCaret", { fg = accent, bg = "NONE" })

  -- Selected row: full-width bg tint + bold so the current item reads clearly.
  set_hl(0, "MiniPickMatchCurrent", { bg = sel_bg, bold = true })
  -- Marked items (toggled with <C-x>): tint toward the structure accent.
  set_hl(0, "MiniPickMatchMarked", { fg = accent, bg = "NONE", italic = true })
  -- Fuzzy-matched character ranges pop in the search-accent yellow.
  set_hl(0, "MiniPickMatchRanges", { fg = query, bg = "NONE", bold = true })
end)

-- Manage and expand snippets (templates for a frequently used text).
-- Typical workflow is to type snippet's (configurable) prefix and expand it
-- into a snippet session.
--
-- How to manage snippets:
-- - 'mini.snippets' itself doesn't come with preconfigured snippets. Instead there
--   is a flexible system of how snippets are prepared before expanding.
--   They can come from pre-defined path on disk, 'snippets/' directories inside
--   config or plugins, defined inside `setup()` call directly.
-- - This config, however, does come with snippet configuration:
--     - 'snippets/global.json' is a file with global snippets that will be
--       available in any buffer
--     - 'after/snippets/lua.json' defines personal snippets for Lua language
--     - 'friendly-snippets' plugin configured in 'plugin/40_plugins.lua' provides
--       a collection of language snippets
--
-- How to expand a snippet in Insert mode:
-- - If you know snippet's prefix, type it as a word and press `<C-j>`. Snippet's
--   body should be inserted instead of the prefix.
-- - If you don't remember snippet's prefix, type only part of it (or none at all)
--   and press `<C-j>`. It should show picker with all snippets that have prefixes
--   matching typed characters (or all snippets if none was typed).
--   Choose one and its body should be inserted instead of previously typed text.
--
-- How to navigate during snippet session:
-- - Snippets can contain tabstops - places for user to interactively adjust text.
--   Each tabstop is highlighted depending on session progression - whether tabstop
--   is current, was or was not visited. If tabstop doesn't yet have text, it is
--   visualized with special "ghost" inline text: • and ∎ by default.
-- - Type necessary text at current tabstop and navigate to next/previous one
--   by pressing `<C-l>` / `<C-h>`.
-- - Repeat previous step until you reach special final tabstop, usually denoted
--   by ∎ symbol. If you spotted a mistake in an earlier tabstop, navigate to it
--   and return back to the final tabstop.
-- - To end a snippet session when at final tabstop, keep typing or go into
--   Normal mode. To force end snippet session, press `<C-c>`.
--
-- See also:
-- - `:h MiniSnippets-overview` - overview of how module works
-- - `:h MiniSnippets-examples` - examples of common setups
-- - `:h MiniSnippets-session` - details about snippet session
-- - `:h MiniSnippets.gen_loader` - list of available loaders
later(function()
  -- Define language patterns to work better with 'friendly-snippets'
  local latex_patterns = { "latex/**/*.json", "**/latex.json" }
  local lang_patterns = {
    tex = latex_patterns,
    plaintex = latex_patterns,
    -- Recognize special injected language of markdown tree-sitter parser
    markdown_inline = { "markdown.json" },
  }

  local snippets = require("mini.snippets")
  local config_path = vim.fn.stdpath("config")
  snippets.setup({
    snippets = {
      -- Always load 'snippets/global.json' from config directory
      snippets.gen_loader.from_file(config_path .. "/snippets/global.json"),
      -- Load from 'snippets/' directory of plugins, like 'friendly-snippets'
      snippets.gen_loader.from_lang({ lang_patterns = lang_patterns }),
    },
    mappings = { expand = "<C-;>" },
  })

  -- By default snippets available at cursor are not shown as candidates in
  -- 'mini.completion' menu. This requires a dedicated in-process LSP server
  -- that will provide them. To have that, uncomment next line (use `gcc`).
  -- MiniSnippets.start_lsp_server()
end)

-- Split and join arguments (regions inside brackets between allowed separators).
-- It uses Lua patterns to find arguments, which means it works in comments and
-- strings but can be not as accurate as tree-sitter based solutions.
-- Each action can be configured with hooks (like add/remove trailing comma).
-- Example usage:
-- - `gS` - toggle between joined (all in one line) and split (each on a separate
--   line and indented) arguments. It is dot-repeatable (see `:h .`).
--
-- See also:
-- - `:h MiniSplitjoin.gen_hook` - list of available hooks
later(function()
  require("mini.splitjoin").setup()
end)

-- Surround actions: add/delete/replace/find/highlight. Working with surroundings
-- is surprisingly common: surround word with quotes, replace `)` with `]`, etc.
-- This module comes with many built-in surroundings, each identified by a single
-- character. It searches only for surrounding that covers cursor and comes with
-- a special "next" / "last" versions of actions to search forward or backward
-- (just like 'mini.ai'). All text editing actions are dot-repeatable (see `:h .`).
--
-- NOTE: mappings are moved off the default `s`-prefix to `gs` so the bare `s`
-- (and `S`) keys are free for 'flash.nvim' (installed in 'plugin/40_plugins.lua':
-- `s` jump, `S` treesitter jump). The action keys keep their mnemonic second
-- letter, just behind `g`: `gsa`/`gsd`/`gsr`/`gsf`/`gsh`.
--
-- Example usage (this may feel intimidating at first, but after practice it
-- becomes second nature during text editing):
-- - `gsaiw)` - *g*o *s*urround *a*dd for *i*nside *w*ord parenthesis (`)`)
-- - `gsdf`   - *g*o *s*urround *d*elete *f*unction call (like `f(var)` -> `var`)
-- - `gsrb[`  - *g*o *s*urround *r*eplace *b*racket (any of [], (), {}) with padded `[`
-- - `gsf*`   - *g*o *s*urround *f*ind right part of `*` pair (like bold in markdown)
-- - `gshf`   - *g*o *s*urround *h*ighlight current *f*unction call
-- - `gsrn{{` - *g*o *s*urround *r*eplace *n*ext curly bracket `{` with padded `{`
-- - `gsdl'`  - *g*o *s*urround *d*elete *l*ast quote pair (`'`)
-- - `vaWgsa<Space>` - *v*isually select *a*round *W*ORD and *g*o *s*urround *a*dd
--                     spaces (`<Space>`)
--
-- See also:
-- - `:h MiniSurround-builtin-surroundings` - list of all supported surroundings
-- - `:h MiniSurround-surrounding-specification` - examples of custom surroundings
-- - `:h MiniSurround-vim-surround-config` - alternative set of action mappings
later(function()
  require("mini.surround").setup({
    -- Moved off `s` to `gs` so `s`/`S` are free for 'flash.nvim'.
    mappings = {
      add = "gsa", -- Add surrounding in Normal and Visual modes
      delete = "gsd", -- Delete surrounding
      find = "gsf", -- Find surrounding (to the right)
      find_left = "gsF", -- Find surrounding (to the left)
      highlight = "gsh", -- Highlight surrounding
      replace = "gsr", -- Replace surrounding
      update_n_lines = "gsn", -- Update `n_lines`
    },
  })
end)

-- Highlight and remove trailspace. Temporarily stops highlighting in Insert mode
-- to reduce noise when typing. Example usage:
-- - `<Leader>ot` - trim all trailing whitespace in a buffer
later(function()
  require("mini.trailspace").setup()
end)

-- Track and reuse file system visits. Every file/directory visit is persistently
-- tracked on disk to later reuse: show in special frecency order, etc. It also
-- supports adding labels to visited paths to quickly navigate between them.
-- Example usage:
-- - `<Leader>fv` - find across all visits
-- - `<Leader>vv` / `<Leader>vV` - add/remove special "core" label to current file
-- - `<Leader>vc` / `<Leader>vC` - show files with "core" label; all or added within
--   current working directory
--
-- See also:
-- - `:h MiniVisits-overview` - overview of how module works
-- - `:h MiniVisits-examples` - examples of common setups
later(function()
  require("mini.visits").setup()
end)

-- Not mentioned here, but can be useful:
-- - 'mini.doc' - needed only for plugin developers.
-- - 'mini.fuzzy' - not really needed on a daily basis.
-- - 'mini.test' - needed only for plugin developers.
