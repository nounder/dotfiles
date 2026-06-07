-- Namespace-import completion from capitalized project files.
--
-- Adds completion candidates for every project file whose *filename* starts with
-- an uppercase letter (e.g. 'Orb.tsx'). Typing "Or" offers `Orb`; accepting it
-- inserts a namespace import at the top of the buffer:
--
--   import * as Orb from "../components/Orb"
--
-- This is intentionally NOT a normal LSP auto-import:
-- - tsserver/vtsls auto-import works on declared *exported symbols*, not on a
--   file's basename, so it never offers "the file as a namespace".
-- - even when it does auto-import a symbol, it only emits named/default imports
--   (`import { Orb }` / `import Orb`), never `import * as Orb`
--   (https://github.com/microsoft/TypeScript/issues/23830, declined).
--
-- So the candidate list comes from filenames and the import edit is synthesized
-- here, client-side. The candidates are merged into 'mini.completion' via the
-- `lsp_completion.process_items` hook (see the seam in 'plugin/30_mini.lua').
--
-- Flow:
-- - `M.candidates(base, buf)` is called synchronously from `process_items`. It
--   reads a per-cwd file cache and returns LSP-shaped completion items.
-- - The cache is filled asynchronously by `M.refresh(cwd)` (spawns the same file
--   command 'mini.pick' uses). `process_items` can't block on it, so the first
--   trigger in a project may return nothing; the async result re-triggers the
--   popup so the candidates appear a tick later.
-- - The cache is invalidated on `:w` of a .ts/.tsx file (registered in the
--   'plugin/35_*.lua' stub) so new/renamed files appear without a restart.

local M = {}

local SOURCE_EXT = {
  ts = true,
  tsx = true,
}

local ENABLED_FT = {
  typescript = true,
  typescriptreact = true,
}

-- Per-cwd cache: cwd -> { items = { { name, path }, ... }, fetching = bool }.
-- `items` is nil until the first successful refresh completes.
local cache = {}

-- Per-buffer memo of the last import scan, keyed by `changedtick`. `candidates`
-- runs on every keystroke, but the imports only change when the buffer does, so
-- a burst of typing reuses one parse instead of re-querying Treesitter each time.
local scan_cache = {} -- buf -> { tick = changedtick, result = {...} }

-- Detect the file-listing tool the same way 'mini.pick' does and return the
-- exact command it would run (see 'mini/pick.lua' H.files_get_tool /
-- H.files_get_command). Those helpers are module-local and not exported, so we
-- replicate the trivial logic to get an identical, gitignore-aware file list.

local files_cmd = nil
local function files_command()
  if files_cmd == nil then
    if vim.fn.executable("rg") == 1 then
      files_cmd = { "rg", "--files", "--color=never" }
    elseif vim.fn.executable("fd") == 1 then
      files_cmd = { "fd", "--type=f", "--color=never" }
    elseif vim.fn.executable("git") == 1 then
      files_cmd = { "git", "-c", "core.quotepath=false", "ls-files", "--cached", "--others", "--exclude-standard" }
    else
      files_cmd = false
    end
  end
  return files_cmd or nil
end

-- Build the cache entry list from raw `rg --files`-style stdout (relative paths).
local function parse_files(cwd, stdout)
  local items = {}
  local seen = {}
  for line in vim.gsplit(stdout or "", "\n", { plain = true }) do
    if line ~= "" then
      local base = line:match("[^/]+$") or line
      local name, ext = base:match("^(.+)%.([^.]+)$")
      -- Keep files with a capitalized basename and a known source extension.
      if name and ext and SOURCE_EXT[ext] and name:match("^%u") and not seen[name] then
        seen[name] = true
        items[#items + 1] = { name = name, path = cwd .. "/" .. line }
      end
    end
  end
  return items
end

-- Asynchronously (re)fill the cache for `cwd`. Non-blocking; on completion it
-- re-triggers the completion popup so freshly cached items show up.
function M.refresh(cwd)
  local entry = cache[cwd]
  if entry and entry.fetching then
    return
  end
  local cmd = files_command()
  if cmd == nil then
    cache[cwd] = { items = {}, fetching = false }
    return
  end
  cache[cwd] = { items = entry and entry.items or nil, fetching = true }

  vim.system(cmd, { cwd = cwd, text = true }, function(out)
    vim.schedule(function()
      local items = (out.code == 0) and parse_files(cwd, out.stdout) or {}
      cache[cwd] = { items = items, fetching = false }
      -- Re-trigger so the just-cached candidates appear in the open popup.
      if vim.fn.mode() == "i" and _G.MiniCompletion ~= nil then
        pcall(MiniCompletion.complete_twostage)
      end
    end)
  end)
end

-- Invalidate the cache for a cwd (called from the BufWritePost autocmd) so the
-- next completion in that project re-scans for new/renamed files.
function M.invalidate(cwd)
  cache[cwd or vim.fn.getcwd()] = nil
end

-- Drop the per-buffer import-scan memo (called from BufDelete/BufWipeout) so the
-- `scan_cache` table doesn't grow unbounded over a long session.
function M.forget_buf(buf)
  scan_cache[buf] = nil
end

-- Split an absolute path into its non-empty segments.
local function segments(path)
  local out = {}
  for seg in vim.gsplit(path, "/", { plain = true }) do
    if seg ~= "" then
      out[#out + 1] = seg
    end
  end
  return out
end

-- Compute a relative import specifier from `from_file` (the buffer being edited)
-- to `to_file` (the target module). The extension is kept (e.g. ".tsx"), so the
-- result is e.g. "./Orb.tsx" or "../components/Orb.tsx".
-- `vim.fs.relpath` only handles the "target inside base" case (returns nil for
-- any '..'), so we compute the relative path ourselves including '..' segments.
local function relative_specifier(from_file, to_file)
  local from = segments(vim.fn.fnamemodify(from_file, ":h"))
  local to = segments(to_file)

  -- Drop the common leading prefix.
  local i = 1
  while i <= #from and i <= #to and from[i] == to[i] do
    i = i + 1
  end

  local parts = {}
  for _ = i, #from do
    parts[#parts + 1] = ".."
  end
  for j = i, #to do
    parts[#parts + 1] = to[j]
  end

  local rel = table.concat(parts, "/")
  -- TS bare specifiers are non-relative imports; force an explicit "./" prefix
  -- when the path doesn't already start by going up ("../").
  if not vim.startswith(rel, ".") then
    rel = "./" .. rel
  end
  return rel
end

-- Treesitter query matching the local binding name of every import form and the
-- whole `import` statement. Captures (TS/TSX grammar):
-- - @ns      `import * as Orb from "..."`   -> binding `Orb`
-- - @default `import Orb from "..."`         -> binding `Orb`
-- - @named   `import { Orb } from "..."`     -> binding `Orb` (also `type Orb`)
-- - @alias   `import { Foo as Orb }`         -> binding is the alias `Orb`
-- - @stmt    the enclosing `import_statement` (for the insert position)
-- When an `import_specifier` has an alias, the in-scope name is the alias, so
-- @alias must override @named for that specifier (handled in `scan_imports`).
local IMPORT_QUERY = [[
  (import_statement
    (import_clause
      [
        (namespace_import (identifier) @ns)
        (identifier) @default
        (named_imports
          (import_specifier name: (identifier) @named alias: (identifier)? @alias))
      ])) @stmt
]]

-- Treesitter parser language for a TS filetype. tsx files use the 'tsx' grammar;
-- plain typescript uses 'typescript'. Returns nil for anything else.
local function ts_lang(buf)
  local ft = vim.bo[buf].filetype
  if ft == "typescriptreact" then
    return "tsx"
  elseif ft == "typescript" then
    return "typescript"
  end
  return nil
end

-- Parse the buffer's imports with Treesitter in a single pass. Returns:
--   names       set of already-imported local binding names (-> dedupe)
--   insert_line 0-based line after the last top-level import (-> where to insert)
-- The TS/TSX parser is already maintained for highlighting, so `get_parser`
-- reuses the existing tree (no extra parse cost in practice). Result is memoized
-- per buffer `changedtick`.
local function scan_imports(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local memo = scan_cache[buf]
  if memo ~= nil and memo.tick == tick then
    return memo.result
  end

  local lang = ts_lang(buf)
  if lang == nil then
    return { names = {}, insert_line = 0 }
  end
  local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
  if not ok or parser == nil then
    return { names = {}, insert_line = 0 }
  end
  local tree = parser:parse()[1]
  if tree == nil then
    return { names = {}, insert_line = 0 }
  end

  local query = vim.treesitter.query.parse(lang, IMPORT_QUERY)
  local names = {}
  local insert_line = 0
  -- Track the most recent @named so a following @alias on the same specifier can
  -- replace it (the alias is the actual local binding).
  local pending_named = nil
  for id, node in query:iter_captures(tree:root(), buf, 0, -1) do
    local cap = query.captures[id]
    local text = vim.treesitter.get_node_text(node, buf)
    if cap == "stmt" then
      local _, _, end_row = node:range()
      -- end_row is the last line of the statement (0-based); insert after it.
      insert_line = math.max(insert_line, end_row + 1)
    elseif cap == "named" then
      names[text] = true
      pending_named = text
    elseif cap == "alias" then
      -- Alias is the in-scope name; drop the original specifier name.
      if pending_named ~= nil then
        names[pending_named] = nil
        pending_named = nil
      end
      names[text] = true
    else -- "ns" | "default"
      names[text] = true
    end
  end

  local result = { names = names, insert_line = insert_line }
  scan_cache[buf] = { tick = tick, result = result }
  return result
end

-- Build the LSP-shaped completion items for `base` in buffer `buf`.
-- Synchronous: reads the cache as-is and kicks off a refresh if empty/missing.
function M.candidates(base, buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not ENABLED_FT[vim.bo[buf].filetype] then
    return {}
  end
  -- Feature is for capitalized names: cheap gate, also avoids noise on lowercase.
  if base == nil or not base:match("^%u") then
    return {}
  end

  local cwd = vim.fn.getcwd()
  local entry = cache[cwd]
  if entry == nil or entry.items == nil then
    M.refresh(cwd) -- async; results land on the next trigger
    return {}
  end

  local from_file = vim.api.nvim_buf_get_name(buf)
  local base_lower = base:lower()
  -- Parse imports once (Treesitter): which names are already imported, and the
  -- line to insert new imports on.
  local imports = scan_imports(buf)
  local line = imports.insert_line
  local out = {}
  for _, file in ipairs(entry.items) do
    -- Cheap prefix gate (case-insensitive). We collect *all* prefix matches and
    -- let the existing mini.fuzzy scorer (in the `process_items` pipeline) rank
    -- them and the menu trim — capping here would drop better matches before
    -- ranking. The loop is just a `startswith` over the cached list, so it stays
    -- cheap even on large projects.
    if vim.startswith(file.name:lower(), base_lower) then
      if file.path ~= from_file and not imports.names[file.name] then
        local specifier = relative_specifier(from_file, file.path)
        out[#out + 1] = {
          label = file.name,
          kind = vim.lsp.protocol.CompletionItemKind.Module,
          insertText = file.name,
          labelDetails = { description = specifier },
          additionalTextEdits = {
            {
              range = {
                start = { line = line, character = 0 },
                ["end"] = { line = line, character = 0 },
              },
              newText = string.format('import * as %s from "%s"\n', file.name, specifier),
            },
          },
          -- nil client_id => 'mini.completion' skips completionItem/resolve
          -- (which would fail for a synthetic item) and applies the edit as-is.
          client_id = nil,
        }
      end
    end
  end
  return out
end

return M
