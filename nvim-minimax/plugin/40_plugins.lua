-- ┌─────────────────────────┐
-- │ Plugins outside of MINI │
-- └─────────────────────────┘
--
-- This file contains installation and configuration of plugins outside of MINI.
-- They significantly improve user experience in a way not yet possible with MINI.
-- These are mostly plugins that provide programming language specific behavior.
--
-- Use this file to install and configure other such plugins.

-- Make concise helpers for installing/adding plugins in two stages
local add, later = MiniDeps.add, MiniDeps.later
local now_if_args = Config.now_if_args

-- Tree-sitter ================================================================

-- Tree-sitter is a tool for fast incremental parsing. It converts text into
-- a hierarchical structure (called tree) that can be used to implement advanced
-- and/or more precise actions: syntax highlighting, textobjects, indent, etc.
--
-- Tree-sitter support is built into Neovim (see `:h treesitter`). However, it
-- requires two extra pieces that don't come with Neovim directly:
-- - Language parsers: programs that convert text into trees. Some are built-in
--   (like for Lua), 'nvim-treesitter' provides many others.
--   NOTE: It requires third party software to build and install parsers.
--   See the link for more info in "Requirements" section of the MiniMax README.
-- - Query files: definitions of how to extract information from trees in
--   a useful manner (see `:h treesitter-query`). 'nvim-treesitter' also provides
--   these, while 'nvim-treesitter-textobjects' provides the ones for Neovim
--   textobjects (see `:h text-objects`, `:h MiniAi.gen_spec.treesitter()`).
--
-- Add these plugins now if file (and not 'mini.starter') is shown after startup.
--
-- Troubleshooting:
-- - Run `:checkhealth vim.treesitter nvim-treesitter` to see potential issues.
-- - In case of errors related to queries for Neovim bundled parsers (like `lua`,
--   `vimdoc`, `markdown`, etc.), manually install them via 'nvim-treesitter'
--   with `:TSInstall <language>`. Be sure to have necessary system dependencies
--   (see MiniMax README section for software requirements).
now_if_args(function()
  add({
    source = "nvim-treesitter/nvim-treesitter",
    -- Update tree-sitter parser after plugin is updated
    hooks = {
      post_checkout = function()
        vim.cmd("TSUpdate")
      end,
    },
    -- Pin to the commit just before the plugin dropped Neovim=0.11 support
    checkout = "90cd6580e720caedacb91fdd587b747a6e77d61f",
  })
  add({
    source = "nvim-treesitter/nvim-treesitter-textobjects",
    -- Pin to the commit corresponding to 'nvim-treesitter' commit
    checkout = "93d60a475f0b08a8eceb99255863977d3a25f310",
  })

  -- Define languages which will have parsers installed and auto enabled
  -- After changing this, restart Neovim once to install necessary parsers. Wait
  -- for the installation to finish before opening a file for added language(s).
  local languages = {
    -- These are already pre-installed with Neovim. Used as an example.
    "lua",
    "vimdoc",
    "markdown",
    -- Inline elements (bold/italic, links, code spans) of markdown. The block
    -- 'markdown' parser injects this one, so both are needed for full highlighting.
    "markdown_inline",
    -- Add here more languages with which you want to use tree-sitter
    -- To see available languages:
    -- - Execute `:=require('nvim-treesitter').get_available()`
    -- - Visit 'SUPPORTED_LANGUAGES.md' file at
    --   https://github.com/nvim-treesitter/nvim-treesitter
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

-- Language servers ===========================================================

-- Language Server Protocol (LSP) is a set of conventions that power creation of
-- language specific tools. It requires two parts:
-- - Server - program that performs language specific computations.
-- - Client - program that asks server for computations and shows results.
--
-- Here Neovim itself is a client (see `:h vim.lsp`). Language servers need to
-- be installed separately based on your OS, CLI tools, and preferences.
-- See note about 'mason.nvim' at the bottom of the file.
--
-- Neovim's team collects commonly used configurations for most language servers
-- inside 'neovim/nvim-lspconfig' plugin.
--
-- Add it now if file (and not 'mini.starter') is shown after startup.
--
-- Troubleshooting:
-- - Run `:checkhealth vim.lsp` to see potential issues.
now_if_args(function()
  add("neovim/nvim-lspconfig")

  -- Use `:h vim.lsp.enable()` to automatically enable language server based on
  -- the rules provided by 'nvim-lspconfig'.
  -- Use `:h vim.lsp.config()` or 'after/lsp/' directory to configure servers.
  -- Each enabled server needs its CLI tool installed and on `$PATH`.
  vim.lsp.enable({
    -- Lua (requires `lua-language-server`). See 'after/lsp/lua_ls.lua'.
    "lua_ls",
    -- TypeScript/JavaScript (requires `vtsls`). See 'after/lsp/vtsls.lua'.
    -- NOTE: don't also enable 'ts_ls' alongside 'vtsls'; pick one.
    "vtsls",
    -- Swift / Objective-C / C / C++ (requires `sourcekit-lsp`, ships with the
    -- Swift/Xcode toolchain). See 'after/lsp/sourcekit.lua'.
    "sourcekit",
    -- Tailwind CSS (requires `tailwindcss-language-server`; install with
    -- `npm i -g @tailwindcss/language-server`). Attaches in Tailwind projects.
    -- See 'after/lsp/tailwindcss.lua'.
    "tailwindcss",
    -- JSON (schema-aware validation/completion). Runs via `bunx` so it only
    -- needs `bun` on `$PATH`. See 'after/lsp/jsonls.lua'.
    "jsonls",
    -- YAML (schema-aware validation/completion). Runs via `bunx` so it only
    -- needs `bun` on `$PATH`. See 'after/lsp/yamlls.lua'.
    "yamlls",
    -- Python (requires `pyright-langserver`; install with `npm i -g pyright`
    -- or `pipx install pyright`). See 'after/lsp/pyright.lua'.
    "pyright",
  })
end)

-- Formatting =================================================================

-- Formatting via 'stevearc/conform.nvim' lives in its own file.
-- See 'plugin/50_formatting.lua'.

-- Snippets ===================================================================

-- Although 'mini.snippets' provides functionality to manage snippet files, it
-- deliberately doesn't come with those.
--
-- The 'rafamadriz/friendly-snippets' is currently the largest collection of
-- snippet files. They are organized in 'snippets/' directory (mostly) per language.
-- 'mini.snippets' is designed to work with it as seamlessly as possible.
-- See `:h MiniSnippets.gen_loader.from_lang()`.
later(function()
  add("rafamadriz/friendly-snippets")
end)

-- Git client =================================================================

later(function()
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
end)

-- Honorable mentions =========================================================

-- 'mason-org/mason.nvim' (a.k.a. "Mason") is a great tool (package manager) for
-- installing external language servers, formatters, and linters. It provides
-- a unified interface for installing, updating, and deleting such programs.
--
-- The caveat is that these programs will be set up to be mostly used inside Neovim.
-- If you need them to work elsewhere, consider using other package managers.
--
-- You can use it like so:
-- now_if_args(function()
--   add('mason-org/mason.nvim')
--   require('mason').setup()
-- end)

-- Beautiful, usable, well maintained color schemes outside of 'mini.nvim' and
-- have full support of its highlight groups. Use if you don't like 'miniwinter'
-- enabled in 'plugin/30_mini.lua' or other suggested 'mini.hues' based ones.
-- MiniDeps.now(function()
--   -- Install only those that you need
--   add('sainnhe/everforest')
--   add('Shatur/neovim-ayu')
--   add('ellisonleao/gruvbox.nvim')
--
--   -- Enable only one
--   vim.cmd('color everforest')
-- end)
