return {
  -- https://github.com/marilari88/neotest-vitest
  -- This doesn't work with local vitest. Also may have problems with nested projects.
  { "marilari88/neotest-vitest" },

  -- https://github.com/nvim-neotest/neotest-python
  { "nvim-neotest/neotest-python" },

  {
    -- https://github.com/nvim-neotest/neotest
    "nvim-neotest/neotest",
    opts = { adapters = {
      "neotest-python",
      "neotest-vitest",
    } },
  },
}
