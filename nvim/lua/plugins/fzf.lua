local function sim(chars)
  local keys = vim.api.nvim_replace_termcodes(chars, true, false, true)

  return function()
    vim.api.nvim_feedkeys(keys, "m", true)
  end
end

return {
  {
    "ibhagwan/fzf-lua",
    opts = {
      oldfiles = {
        cwd_only = true,
        include_current_session = true,
      },
      previewers = {
        builtin = {
          syntax_limit_b = 1024 * 100, -- 100KB
        },
      },
      grep = {
        -- With this change, I can sort of get the same behaviour in live_grep.
        -- ex: > enable --*/plugins/*
        -- I still find this a bit cumbersome. There's probably a better way of doing this.
        -- filter results by a glob, eg. "enabled = false -- */plugins/*"
        rg_glob = true, -- enable glob parsing
        glob_flag = "--iglob", -- case insensitive globs
        glob_separator = "%s%-%-", -- query separator pattern (lua): ' --'
      },
    },

    keys = {
      { "ff", sim("<leader>ff"), expr = true },
      { "fr", sim("<leader>fr"), expr = true },

      { "<leader>fo", "<cmd>FzfLua resume<cr>", desc = "Resume" },
      { "fo", sim("<leader>fo"), expr = true },

      { "<leader>fl", "<cmd>FzfLua grep_curbuf<cr>", desc = "Search in Current Buffer" },
      { "fl", sim("<leader>fl"), expr = true },
    },
  },
}
