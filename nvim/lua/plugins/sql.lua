return {
  --   {
  --     "kristijanhusak/vim-dadbod-ui",
  --     keys = {
  --       { "<leader>D", "<cmd>DBUIToggle<CR>",                                desc = "Toggle DBUI" },
  --       { "<leader>S", "<cmd>call <sid>method('execute_query')<CR>",         mode = "n",          desc = "Execute DB query (file)" },
  --       { "<leader>S", "<cmd><C-U>call <sid>method('execute_query', 1)<CR>", mode = "v",          desc = "Execute DB query (selected)" },
  --     },
  --     init = function()
  --       local data_path = vim.fn.stdpath("data")
  --
  --       vim.g.db_ui_auto_execute_table_helpers = 1
  --       vim.g.db_ui_save_location = data_path .. "/dadbod_ui"
  --       vim.g.db_ui_show_database_icon = true
  --       vim.g.db_ui_tmp_query_location = data_path .. "/dadbod_ui/tmp"
  --       vim.g.db_ui_use_nerd_fonts = true
  --       vim.g.db_ui_use_nvim_notify = true
  --
  --       -- NOTE: The default behavior of auto-execution of queries on save is disabled
  --       -- this is useful when you have a big query that you don't want to run every time
  --       -- you save the file running those queries can crash neovim to run use the
  --       -- default keymap: <leader>S
  --       vim.g.db_ui_execute_on_save = false
  --     end,
  --   }
}
