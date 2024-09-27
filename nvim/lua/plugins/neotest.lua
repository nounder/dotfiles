return {
  -- This doesn't work with local vitest. Also may have problems with nested projects.
  { "marilari88/neotest-vitest" },

  { "nvim-neotest/neotest-python" },

  {
    "nvim-neotest/neotest",
    opts = { adapters = {
      "neotest-python",
      "neotest-vitest",
    } },
  },
}
