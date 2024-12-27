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
      -- Keybinding for searching within the current buffer
      {
        "<leader>fl",
        function()
          require("fzf-lua").grep_curbuf()
        end,
        desc = "Search in Current Buffer",
      },

      {
        "<leader>fo",
        function()
          require("fzf-lua").oldfiles()
        end,
        desc = "Search in Current Buffer",
      },
    },
  },
}
