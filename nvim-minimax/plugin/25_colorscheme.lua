-- ┌─────────────┐
-- │ Color scheme │
-- └─────────────┘
--
-- This file builds and applies the active color scheme. It is sourced before
-- 'plugin/30_mini.lua' (file names in 'plugin/' are loaded alphabetically) so
-- colors are set as early as possible, before the first screen draw.
--
-- It uses 'mini.base16' (part of 'mini.nvim', already bootstrapped in 'init.lua')
-- to turn a fixed 16-color palette into a full colorscheme, then strips
-- backgrounds for terminal transparency and applies a few highlight overrides.

-- 'MiniDeps' is set up in 'init.lua'; `now()` runs immediately (needed so colors
-- are correct on the first draw, including `nvim -- path/to/file` startup).
local now = MiniDeps.now

-- Build a base16 color scheme from a fixed 16-color palette. 'mini.base16' comes
-- with 'mini.nvim' and turns the 16 colors (base00 darkest bg .. base07 lightest
-- fg, base08..base0F accents) into a full colorscheme, including all the MiniMax
-- UI highlight groups (statusline, completion, pickers, diff signs).
--
-- Palette below is base16-gruvbox (gruvbox-dark-hard); it matches the one used in
-- '~/dotfiles/nvim'. To use a different base16 theme, swap these 16 hex values
-- (find palettes at https://github.com/tinted-theming).
--
-- See also:
-- - `:h MiniBase16.setup` - all options (use_cterm, name, plugins)
-- - `:h mini.nvim-color-schemes` - the bundled 'mini.hues' schemes (miniwinter,
--   minispring, ...); still available via `:colorscheme` for the session
-- - `:h MiniHues-examples` - how to define highlighting with 'mini.hues'
now(function()
  -- base16-gruvbox palette (kept in a local so the overrides below can reference
  -- individual slots, e.g. `p.base0D`).
  local p = {
    base00 = "#1d2021", -- darkest bg (Normal background)
    base01 = "#3c3836", -- lighter bg (status, line highlight)
    base02 = "#504945", -- selection bg
    base03 = "#665c54", -- comments, line numbers
    base04 = "#bdae93", -- dark fg (status fg)
    base05 = "#d5c4a1", -- default fg
    base06 = "#ebdbb2", -- light fg
    base07 = "#fbf1c7", -- lightest fg
    base08 = "#fb4934", -- red    - variables, errors
    base09 = "#fe8019", -- orange - numbers, constants
    base0A = "#fabd2f", -- yellow - classes, search
    base0B = "#b8bb26", -- green  - strings
    base0C = "#8ec07c", -- cyan   - escapes, regex
    base0D = "#83a598", -- blue   - functions
    base0E = "#d3869b", -- purple - keywords
    base0F = "#d65d0e", -- brown  - deprecated, tags
  }
  -- `use_cterm = true` also sets terminal (cterm) colors for non-truecolor terminals.
  require("mini.base16").setup({ palette = p, use_cterm = true })

  -- 'mini.base16' applies highlights directly and leaves `g:colors_name` unset.
  -- Set it so plugins/statuslines that read the active scheme name see a value.
  vim.g.colors_name = "base16-gruvbox"

  -- Make the active color scheme transparent by stripping background colors, so
  -- the terminal's own background / wallpaper shows through.
  -- NOTE: requires actual transparency from the terminal emulator (a transparent
  -- window in iTerm2/Ghostty/Kitty/WezTerm/etc.) - Neovim can only remove its
  -- background, not create see-through. There is no pre-made transparent scheme;
  -- 'mini.colors' generates it on the fly via `:add_transparency()`.
  --
  -- `resolve_links()` first is required: `add_transparency()` skips linked groups
  -- (see `:h MiniColors-colorscheme:add_transparency()`).
  require("mini.colors")
    .get_colorscheme()
    :resolve_links()
    :add_transparency({
      general = true, -- main editor background (Normal)
      float = true, -- floating windows (completion, hover, pickers)
      statusline = true, -- 'mini.statusline'
      statuscolumn = true, -- sign/number/fold column, diagnostic signs
      tabline = true,
      winbar = true,
    })
    :apply()

  local set_hl = vim.api.nvim_set_hl

  for _, g in ipairs({
    "DiagnosticFloatingError",
    "DiagnosticFloatingWarn",
    "DiagnosticFloatingInfo",
    "DiagnosticFloatingHint",
    "DiagnosticFloatingOk",
  }) do
    set_hl(0, g, { fg = vim.api.nvim_get_hl(0, { name = g }).fg, bg = "NONE" })
  end

  for _, g in ipairs({
    "MiniClueBorder",
    "MiniClueDescGroup",
    "MiniClueDescSingle",
    "MiniClueNextKey",
    "MiniClueNextKeyWithPostkeys",
    "MiniClueSeparator",
    "MiniClueTitle",
  }) do
    local h = vim.api.nvim_get_hl(0, { name = g })
    h.bg, h.ctermbg = "NONE", "NONE"
    set_hl(0, g, h)
  end

  -- 'mini.base16' ships the `*Sel` groups with `reverse = true`, which flips
  -- `Pmenu`'s cream fg into the selection bg (the look we want) but ALSO inverts
  -- the LSP kind chip's coloured fg ('mini.completion' via
  -- `MiniIcons.tweak_lsp_kind`) into a coloured background block. So instead of
  -- `reverse`, set an explicit cream bg (base05) + dark fg (base00): this forces
  -- every column's text dark regardless of its own colour, kind chip included.
  set_hl(0, "PmenuSel", { bg = p.base05, fg = p.base00 })
  set_hl(0, "PmenuKindSel", { bg = p.base05, fg = p.base00 })
  set_hl(0, "PmenuExtraSel", { bg = p.base05, fg = p.base00 })
  set_hl(0, "PmenuMatchSel", { bg = p.base05, fg = p.base00, bold = true })

  -- Make functions/identifiers/variables blue (base0D) instead of base16 default.
  set_hl(0, "Identifier", { fg = p.base0D })
  set_hl(0, "Function", { fg = p.base0D })
  set_hl(0, "@variable", { fg = p.base0D })
  set_hl(0, "@module", { link = "Type" })
  set_hl(0, "@property", { fg = p.base05 })
  set_hl(0, "@variable.member", { fg = p.base05 })
  set_hl(0, "@lsp.type.property", { fg = p.base05 })
  set_hl(0, "NonText", { fg = p.base03 })

  -- mini.diff sign colors (analogous to dotfiles' GitSigns overrides).
  set_hl(0, "MiniDiffSignAdd", { bg = "NONE", fg = p.base0B })
  set_hl(0, "MiniDiffSignChange", { bg = "NONE", fg = p.base0D })
  set_hl(0, "MiniDiffSignDelete", { bg = "NONE", fg = p.base08 })

  -- Neogit theming (this config uses Neogit, set up in 'plugin/40_plugins.lua').
  -- Mix toward base00 for subtle diff backgrounds, like dotfiles does.
  local function mix(a, b, t)
    local function c(h)
      return tonumber(h, 16)
    end
    local ar, ag, ab = c(a:sub(2, 3)), c(a:sub(4, 5)), c(a:sub(6, 7))
    local br, bg, bb = c(b:sub(2, 3)), c(b:sub(4, 5)), c(b:sub(6, 7))
    return string.format(
      "#%02x%02x%02x",
      math.floor(ar + (br - ar) * t),
      math.floor(ag + (bg - ag) * t),
      math.floor(ab + (bb - ab) * t)
    )
  end
  local diff_add_bg = mix(p.base00, p.base0B, 0.15)
  local diff_del_bg = mix(p.base00, p.base08, 0.15)

  set_hl(0, "NeogitDiffAddInline", { bg = "NONE", fg = p.base0B, underline = true })
  set_hl(0, "NeogitDiffDeleteInline", { bg = "NONE", fg = p.base08, underline = true })
  set_hl(0, "NeogitDiffAdd", { bg = diff_add_bg, fg = p.base0B })
  set_hl(0, "NeogitDiffAddHighlight", { bg = diff_add_bg, fg = p.base0B })
  set_hl(0, "NeogitDiffDelete", { bg = diff_del_bg, fg = p.base08 })
  set_hl(0, "NeogitDiffDeleteHighlight", { bg = diff_del_bg, fg = p.base08 })
  set_hl(0, "NeogitDiffContext", { bg = "NONE" })
  set_hl(0, "NeogitDiffContextHighlight", { bg = "NONE" })
  set_hl(0, "NeogitBranch", { fg = p.base0D, bold = true })
  set_hl(0, "NeogitBranchHead", { fg = p.base0D, bold = true, underline = true })
  set_hl(0, "NeogitChangeModified", { fg = p.base0D, bold = true, italic = true })
  set_hl(0, "NeogitChangeAdded", { fg = p.base0B, bold = true, italic = true })
  set_hl(0, "NeogitChangeNewFile", { fg = p.base0B, bold = true, italic = true })
  set_hl(0, "NeogitChangeDeleted", { fg = p.base08, bold = true, italic = true })
  set_hl(0, "NeogitChangeRenamed", { fg = p.base0E, bold = true, italic = true })
  set_hl(0, "NeogitChangeUpdated", { fg = p.base09, bold = true, italic = true })
  set_hl(0, "NeogitChangeCopied", { fg = p.base0C, bold = true, italic = true })
  set_hl(0, "NeogitChangeUnmerged", { fg = p.base0A, bold = true, italic = true })

  -- Keep Neogit diff context transparent even after its buffers set up their own
  -- highlights (mirrors the dotfiles autocmd).
  Config.new_autocmd("FileType", "Neogit*", function()
    vim.opt_local.cursorline = false
    set_hl(0, "NeogitDiffContext", { bg = "NONE" })
    set_hl(0, "NeogitDiffContextHighlight", { bg = "NONE" })
    set_hl(0, "NeogitDiffContextCursor", { bg = "NONE" })
  end, "Keep Neogit diff context transparent")
end)

-- Prefer a bundled 'mini.hues'-based scheme instead? Replace the
-- `require('mini.base16').setup(...)` call above with one of these (the
-- transparency block still applies to whatever is active):
-- now(function() vim.cmd('colorscheme miniwinter') end)
-- now(function() vim.cmd('colorscheme minispring') end)
-- now(function() vim.cmd('colorscheme minisummer') end)
-- now(function() vim.cmd('colorscheme miniautumn') end)
-- now(function() vim.cmd('colorscheme randomhue') end)
