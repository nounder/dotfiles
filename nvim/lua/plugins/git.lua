local Snacks = require("snacks")

return {
  {
    -- https://github.com/NeogitOrg/neogit
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      disable_hint = true,
    },
    keys = {
      {
        "<leader>gg",
        "<cmd>Neogit kind=replace<CR>",
        desc = "Open Git status (full)",
      },
    },
  },

  {
    -- https://github.com/lewis6991/gitsigns.nvim
    "lewis6991/gitsigns.nvim",
    opts = {
      diff_opts = {
        algorithm = "patience",
      },
    },
    keys = {
      {
        "<leader>ud",
        "<cmd>Gitsigns toggle_deleted<CR>",
        desc = "Toggle deleted lines",
      },
      {
        "<leader>uw",
        "<cmd>Gitsigns toggle_word_diff<CR>",
        desc = "Toggle word diff",
      },
    },
  },

  {
    -- https://github.com/sindrets/diffview.nvim
    "sindrets/diffview.nvim",
    -- cannot be lazy because Snacks overwrittes keybinding here
    lazy = false,
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
    },
    opts = {
      enhanced_diff_hl = true,
      keymaps = {
        view = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        },
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        },
        file_history_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        },
      },
      hooks = {
        diff_buf_read = function()
          -- Disable swap files for diff buffers to avoid E325 errors
          vim.opt_local.swapfile = false
          -- Disable folding by default
          vim.opt_local.foldenable = false
        end,
        view_opened = function()
          -- Set tab name when diffview opens
          vim.cmd("silent! file <diffview>")

          -- Focus on the main diff window
          local view = require("diffview.lib").get_current_view()
          if view and view.cur_layout then
            local main_win = view.cur_layout:get_main_win()
            if main_win then
              vim.api.nvim_set_current_win(main_win.id)
            end
          end
        end,
      },
    },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>" },
    },
    init = function()
      -- Disable highlight for added and modified lines,
      -- and underline changed text
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.api.nvim_set_hl(0, "DiffAdd", { bg = "none", fg = "none" })
          vim.api.nvim_set_hl(0, "DiffChange", { bg = "none", fg = "none" })
          vim.api.nvim_set_hl(0, "DiffText", { bg = "none", fg = "none", underline = true })
        end,
      })

      -- Close all diffview buffers before exiting nvim
      vim.api.nvim_create_autocmd("VimLeavePre", {
        pattern = "*",
        callback = function()
          -- Iterate over all buffers to find diffview buffers
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) then
              local ft = vim.bo[buf].filetype
              -- Check if buffer is a diffview buffer
              if ft == "DiffviewFiles" or ft == "DiffviewFileHistory" then
                -- Switch to the diffview buffer and close it
                vim.api.nvim_set_current_buf(buf)
                vim.cmd("DiffviewClose")
                break
              end
            end
          end
        end,
      })
    end,
  },

  {
    -- https://github.com/ruifm/gitlinker.nvim
    "ruifm/gitlinker.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- required
    },
  },

  {
    -- https://github.com/tpope/vim-fugitive
    "tpope/vim-fugitive",
    enabled = true,
    keys = {
      {
        "<leader>gb",
        "<cmd>G blame<CR>",
      },
      {
        "<leader>gc",
        "<cmd>G commit<CR>",
      },
      -- {
      --   "<leader>gd",
      --   "<cmd>G diff<CR>",
      -- },
      {
        "<leader>gl",
        "<cmd>G log<CR>",
      },
      {
        "<leader>gx",
        "<cmd>Gvdiff<CR>",
      },
      -- {
      --   "<leader>gg",
      --   "<cmd>tabnew | Git | only<CR>",
      --   desc = "Open Git status (full)",
      -- },
      {
        "<leader>gp",
        "<cmd>Git push<CR>",
        desc = "Git push",
      },
      {
        "<leader>gP",
        "<cmd>Git pull<CR>",
        desc = "Git pull",
      },

      {
        "<leader>gP",
        "<cmd>Git pull<CR>",
        desc = "Git pull",
      },
      {
        "<leader>gb",
        Snacks.picker.git_branches,
        desc = "Git pull",
      },
      {
        "<leader>gB",
        "<Cmd>G blame<CR>",
        desc = "Git blame",
      },
      {
        "<leader>gs",
        Snacks.picker.git_status,
        desc = "Git status",
      },
      {
        "<leader>gll",
        Snacks.picker.git_log_line,
        desc = "Git pull",
      },
      {
        "<leader>glf",
        Snacks.picker.git_log_file,
        desc = "Git pull",
      },
      {
        "<leader>gll",
        Snacks.picker.git_log_line,
        desc = "Git pull",
      },
    },
  },
  {
    -- https://github.com/tpope/vim-rhubarb
    -- Adds :GBrowse command
    -- Adds omni-completion for git messages
    "tpope/vim-rhubarb",
    dependencies = {
      "tpope/vim-fugitive", -- required
    },
  },
  {
    -- https://github.com/akinsho/git-conflict.nvim
    -- Adds :GitConflict* commands
    "akinsho/git-conflict.nvim",
    version = "*",
    config = true,
  },
}
