return {
  {
    -- https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-base16.md
    "nvim-mini/mini.nvim",
    lazy = false,
    priority = 1000,
  },

  {
    -- https://github.com/folke/tokyonight.nvim
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },

  {
    -- https://github.com/LazyVim/LazyVim
    "LazyVim/LazyVim",
    priority = 1000,
    opts = {
      colorscheme = function()
        local p = {
          base00 = "#1d2021",
          base01 = "#3c3836",
          base02 = "#504945",
          base03 = "#665c54",
          base04 = "#bdae93",
          base05 = "#d5c4a1",
          base06 = "#ebdbb2",
          base07 = "#fbf1c7",
          base08 = "#fb4934", -- red
          base09 = "#fe8019", -- orange
          base0A = "#fabd2f", -- yellow
          base0B = "#b8bb26", -- green
          base0C = "#8ec07c", -- cyan
          base0D = "#83a598", -- blue
          base0E = "#d3869b", -- magenta
          base0F = "#d65d0e", -- brown
        }
        require("mini.base16").setup({ palette = p, use_cterm = true })
        for _, g in ipairs({ "Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn", "EndOfBuffer", "MsgArea", "StatusLine", "StatusLineNC" }) do
          vim.api.nvim_set_hl(0, g, { bg = "NONE" })
        end

        local function mix(a, b, t)
          local function c(h) return tonumber(h, 16) end
          local ar, ag, ab = c(a:sub(2, 3)), c(a:sub(4, 5)), c(a:sub(6, 7))
          local br, bg, bb = c(b:sub(2, 3)), c(b:sub(4, 5)), c(b:sub(6, 7))
          return string.format("#%02x%02x%02x",
            math.floor(ar + (br - ar) * t),
            math.floor(ag + (bg - ag) * t),
            math.floor(ab + (bb - ab) * t))
        end
        local diff_add_bg = mix(p.base00, p.base0B, 0.15)
        local diff_del_bg = mix(p.base00, p.base08, 0.15)

        vim.api.nvim_set_hl(0, "StatusLine", { link = "Normal" })
        vim.api.nvim_set_hl(0, "MsgArea", { fg = p.base04 })
        vim.api.nvim_set_hl(0, "BlinkCmpGhostText", { fg = p.base03 })
        vim.api.nvim_set_hl(0, "NonText", { fg = p.base03 })
        vim.api.nvim_set_hl(0, "GitSignsAdd", { bg = "NONE", fg = p.base0B })
        vim.api.nvim_set_hl(0, "GitSignsChange", { bg = "NONE", fg = p.base0D })
        vim.api.nvim_set_hl(0, "GitSignsDelete", { bg = "NONE", fg = p.base08 })
        vim.api.nvim_set_hl(0, "GitSignsTopdelete", { bg = "NONE", fg = p.base08 })
        vim.api.nvim_set_hl(0, "GitSignsChangedelete", { bg = "NONE", fg = p.base09 })
        vim.api.nvim_set_hl(0, "GitSignsUntracked", { bg = "NONE", fg = p.base0A })
        vim.api.nvim_set_hl(0, "NeogitDiffAddInline", { bg = "NONE", fg = p.base0B, underline = true })
        vim.api.nvim_set_hl(0, "NeogitDiffDeleteInline", { bg = "NONE", fg = p.base08, underline = true })
        vim.api.nvim_set_hl(0, "NeogitDiffAdd", { bg = diff_add_bg, fg = p.base0B })
        vim.api.nvim_set_hl(0, "NeogitDiffAddHighlight", { bg = diff_add_bg, fg = p.base0B })
        vim.api.nvim_set_hl(0, "NeogitDiffDelete", { bg = diff_del_bg, fg = p.base08 })
        vim.api.nvim_set_hl(0, "NeogitDiffDeleteHighlight", { bg = diff_del_bg, fg = p.base08 })
        vim.api.nvim_set_hl(0, "NeogitDiffContext", { bg = "NONE" })
        vim.api.nvim_set_hl(0, "NeogitDiffContextHighlight", { bg = "NONE" })
        vim.api.nvim_set_hl(0, "NeogitBranch", { fg = p.base0D, bold = true })
        vim.api.nvim_set_hl(0, "NeogitBranchHead", { fg = p.base0D, bold = true, underline = true })
        vim.api.nvim_set_hl(0, "NeogitChangeModified", { fg = p.base0D, bold = true, italic = true })
        vim.api.nvim_set_hl(0, "NeogitChangeAdded", { fg = p.base0B, bold = true, italic = true })
        vim.api.nvim_set_hl(0, "NeogitChangeNewFile", { fg = p.base0B, bold = true, italic = true })
        vim.api.nvim_set_hl(0, "NeogitChangeDeleted", { fg = p.base08, bold = true, italic = true })
        vim.api.nvim_set_hl(0, "NeogitChangeRenamed", { fg = p.base0E, bold = true, italic = true })
        vim.api.nvim_set_hl(0, "NeogitChangeUpdated", { fg = p.base09, bold = true, italic = true })
        vim.api.nvim_set_hl(0, "NeogitChangeCopied", { fg = p.base0C, bold = true, italic = true })
        vim.api.nvim_set_hl(0, "NeogitChangeUnmerged", { fg = p.base0A, bold = true, italic = true })
        vim.api.nvim_set_hl(0, "SnacksPickerDir", { link = "Normal" })

        vim.api.nvim_create_autocmd("FileType", {
          pattern = "Neogit*",
          callback = function()
            vim.opt_local.cursorline = false
            vim.api.nvim_set_hl(0, "NeogitDiffContext", { bg = "NONE" })
            vim.api.nvim_set_hl(0, "NeogitDiffContextHighlight", { bg = "NONE" })
            vim.api.nvim_set_hl(0, "NeogitDiffContextCursor", { bg = "NONE" })
          end,
        })
      end,
    },
  },
}
