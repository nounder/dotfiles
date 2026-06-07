-- Wires up 'lua/ts_imports.lua', which adds completion candidates for project
-- files with a capitalized filename (e.g. 'Orb.tsx'). Typing "Or" offers `Orb`
-- and accepting it inserts `import * as Orb from "..."`.
--
-- The candidates themselves are merged into the completion menu by the
-- `process_items` seam in 'plugin/30_mini.lua'. This file only registers the
-- bookkeeping autocmds so caches stay fresh and bounded without a restart.
--
-- See 'lua/ts_imports.lua' for the full design and rationale.

local later = MiniDeps.later

later(function()
  -- Invalidate the per-cwd file cache whenever a source file is written, so the
  -- next completion re-scans. Debounce isn't needed: invalidation is O(1) and
  -- the actual (async) rescan only happens on the next completion trigger.
  Config.new_autocmd("BufWritePost", { "*.ts", "*.tsx" }, function()
    require("ts_imports").invalidate(vim.fn.getcwd())
  end, "Invalidate TS namespace-import file cache")

  -- Drop the per-buffer import-scan memo when a buffer goes away, so the cache
  -- doesn't grow over a long session.
  Config.new_autocmd({ "BufDelete", "BufWipeout" }, nil, function(ev)
    require("ts_imports").forget_buf(ev.buf)
  end, "Forget TS namespace-import buffer scan cache")
end)
