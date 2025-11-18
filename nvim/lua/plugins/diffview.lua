return {
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
        diff_buf_read = function(bufnr)
          -- Disable swap files for diff buffers to avoid E325 errors
          vim.opt_local.swapfile = false
          -- Disable folding by default
          vim.opt_local.foldenable = false

          -- Update Gitsigns base for local file buffers only (not diffview:// buffers)
          local bufname = vim.api.nvim_buf_get_name(bufnr)
          if not bufname:match("^diffview://") then
            local view = require("diffview.lib").get_current_view()
            ---@diagnostic disable-next-line: undefined-field
            local rev_arg = view and view.rev_arg
            if rev_arg then
              vim.defer_fn(function()
                vim.api.nvim_buf_call(bufnr, function()
                  vim.cmd("silent! Gitsigns change_base " .. rev_arg)
                end)
              end, 100)
            end
          end
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

      -- Make q keybinding work in diffview://null buffers
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "diffview://*",
        callback = function(ev)
          vim.keymap.set("n", "q", "<cmd>DiffviewClose<cr>", { buffer = ev.buf, desc = "Close diffview" })
        end,
      })
    end,
  },
}
