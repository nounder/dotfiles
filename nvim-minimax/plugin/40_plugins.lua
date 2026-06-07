local add, later = MiniDeps.add, MiniDeps.later
local now_if_args = Config.now_if_args

now_if_args(function()
  add({
    source = "nvim-treesitter/nvim-treesitter",
    hooks = {

      -- Update tree-sitter parser after plugin is updated
      post_checkout = function()
        vim.cmd("TSUpdate")
      end,
    },
    checkout = "90cd6580e720caedacb91fdd587b747a6e77d61f",
  })
  add({
    source = "nvim-treesitter/nvim-treesitter-textobjects",
    checkout = "93d60a475f0b08a8eceb99255863977d3a25f310",
  })

  local languages = {
    "lua",
    "vimdoc",
    "markdown",
    "markdown_inline",
    "python",
    "typescript",
    "tsx",
    "javascript",
    "json",
    "yaml",
    "bash",
    "swift",
    "c",
    "cpp",
    "css",
    "html",
    "toml",
    "diff",
    "zig",
    "rust",
    "go",
    "sql",
    "dockerfile",
    "regex",
    -- Available languages: `:=require('nvim-treesitter').get_available()`
  }
  local isnt_installed = function(lang)
    return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then
    require("nvim-treesitter").install(to_install)
  end

  -- Enable tree-sitter after opening a file for a target language
  local filetypes = {}
  for _, lang in ipairs(languages) do
    for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
      table.insert(filetypes, ft)
    end
  end
  local ts_start = function(ev)
    vim.treesitter.start(ev.buf)
  end
  Config.new_autocmd("FileType", filetypes, ts_start, "Start tree-sitter")
end)

now_if_args(function()
  add("neovim/nvim-lspconfig")

  vim.lsp.enable({
    "lua_ls",
    "vtsls",
    "sourcekit",
    "tailwindcss",
    "jsonls",
    "yamlls",
    "pyright",
  })
end)

-- 'folke/flash.nvim' adds label-based motions: it shows short labels at match
-- locations and jumps where you pick.
later(function()
  add("folke/flash.nvim")
  require("flash").setup()

  vim.keymap.set({ "n", "x", "o" }, "s", function()
    require("flash").jump()
  end, { desc = "Flash" })
  vim.keymap.set({ "n", "x", "o" }, "S", function()
    require("flash").treesitter()
  end, { desc = "Flash Treesitter" })
  vim.keymap.set("o", "r", function()
    require("flash").remote()
  end, { desc = "Remote Flash" })
  vim.keymap.set({ "o", "x" }, "R", function()
    require("flash").treesitter_search()
  end, { desc = "Treesitter Search" })
  vim.keymap.set("c", "<C-s>", function()
    require("flash").toggle()
  end, { desc = "Toggle Flash Search" })
  -- Simulate nvim-treesitter incremental selection.
  local ts_incremental = function()
    require("flash").treesitter({
      actions = { ["<C-Space>"] = "next", ["<BS>"] = "prev", ["<C-@>"] = "next" },
    })
  end
  vim.keymap.set({ "n", "x", "o" }, "<C-Space>", ts_incremental, { desc = "Treesitter Incremental Selection" })
  vim.keymap.set({ "n", "x", "o" }, "<C-@>", ts_incremental, { desc = "Treesitter Incremental Selection" })
end)

-- Git client a'la magit
local function load_neogit()
  add({
    source = "NeogitOrg/neogit",
    depends = { "nvim-lua/plenary.nvim" },
  })

  -- See `:h neogit` and https://github.com/NeogitOrg/neogit for all options.
  require("neogit").setup({
    -- Don't show the keybinding hints at the top of Neogit buffers.
    disable_hint = true,
    -- Highlight diffs in Neogit buffers via tree-sitter.
    treesitter_diff_highlight = true,
    -- Commit graph style. "kitty" uses the Kitty terminal graphics protocol
    -- (renders best in Kitty/Ghostty); switch to "unicode" for other terminals.
    graph_style = "kitty",
    commit_editor = {
      -- Open the commit message editor in its own tab page.
      kind = "tab",
      -- Show the staged diff alongside the message in a vertical split.
      staged_diff_split_kind = "vsplit",
    },
    integrations = {
      -- Reuse 'mini.pick' for selectors instead of pulling in telescope/fzf.
      -- ('mini.pick' is set up in 'plugin/30_mini.lua'.)
      mini_pick = true,
      -- No diffview.nvim; rely on Neogit's own diffs + 'mini.diff' in buffers.
      -- (Dotfiles uses diffview=true; minimax deliberately keeps mini.diff.)
      diffview = false,
    },
    -- Open the status buffer in its own tab page rather than a floating window.
    kind = "tab",
  })
end

-- The stub forwards args/range/bang to Neogit's real `:Neogit` after loading.
vim.api.nvim_create_user_command("Neogit", function(opts)
  -- Drop the stub so `add()`/'plugin/neogit.lua' can install the real command.
  vim.api.nvim_del_user_command("Neogit")
  load_neogit()
  vim.cmd(("Neogit%s %s"):format(opts.bang and "!" or "", opts.args))
end, {
  nargs = "*",
  bang = true,
  desc = "Load and open Neogit",
})

-- ┌────────────┐
-- │ Formatting │
-- └────────────┘
--
-- The 'stevearc/conform.nvim' plugin is a good and maintained solution for easier
-- formatting setup. This config mirrors the LazyVim setup in
-- '~/dotfiles/nvim/lua/plugins/formatting.lua'.
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
        -- `dprint` is a `#!/usr/bin/env bun` shim. A GUI-launched Neovim gets the
        -- bare launchd PATH (no `~/.bun/bin` or `/opt/homebrew/bin`), so the shebang
        -- can't find `bun`, dprint exits non-zero ("unknown error" in conform's log),
        -- and conform falls back to the much slower LSP formatter. Invoke via
        -- `bunx --no-install dprint` and inject a PATH that includes bun so it works
        -- regardless of how nvim was launched.
        -- Absolute path: conform's availability check runs `vim.fn.executable(command)`
        -- against the (possibly bare) launchd PATH, so a bare "bunx" would read as
        -- unavailable under a GUI nvim before the `env` override below ever applies.
        command = vim.fn.executable("bunx") == 1 and "bunx" or "/opt/homebrew/bin/bunx",
        args = { "--no-install", "dprint", "fmt", "--stdin", "$FILENAME" },
        stdin = true,
        env = {
          PATH = vim.fn.expand("~/.bun/bin") .. ":/opt/homebrew/bin:" .. (vim.env.PATH or "/usr/bin:/bin"),
        },
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
