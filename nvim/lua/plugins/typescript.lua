-- Define a custom handler for signature help
function custom_signature_help_handler(err, result, ctx, config)
  if not result or not result.signatures then
    return
  end

  -- Extract the active signature
  local signature = result.signatures[result.activeSignature or 1]
  if not signature then
    return
  end

  -- Custom formatting function
  local function format_signature(sig)
    local label = sig.label
    local params = sig.parameters or {}
    local formatted = {}

    -- Split the signature into lines for readability
    table.insert(formatted, "Function: " .. label:match("^[^%(]+")) -- Function name
    table.insert(formatted, "Parameters:")

    for i, param in ipairs(params) do
      local param_text = param.label
      if type(param_text) == "table" then
        param_text = label:sub(param_text[1], param_text[2])
      end
      table.insert(formatted, string.format("  %d. %s", i, param_text))
    end

    return formatted
  end

  -- Create a floating window with formatted content
  local lines = format_signature(signature)
  local bufnr, winnr = vim.lsp.util.open_floating_preview(lines, "markdown", {
    border = "rounded", -- Customize border (single, double, rounded, etc.)
    max_width = 80, -- Limit width for readability
    focusable = false,
  })

  -- Optional: Set highlighting for better visuals
  vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")
end

return {
  {
    "neovim/nvim-lspconfig",
    enabled = not vim.env.NVIM_LIGHTWEIGHT,
    opts = {
      servers = {
        vtsls = {
          handlers = {
            ["textDocument/hover"] = custom_signature_help_handler,
            ["textDocument/publishDiagnostics"] = function(_, result, ctx, config)
              if result.diagnostics == nil then
                return
              end

              -- ignore some tsserver diagnostics
              local idx = 1
              while idx <= #result.diagnostics do
                local entry = result.diagnostics[idx]

                local formatter = require("format-ts-errors")[entry.code]
                entry.message = formatter and formatter(entry.message) or entry.message

                -- codes: https://github.com/microsoft/TypeScript/blob/main/src/compiler/diagnosticMessages.json
                if entry.code == 80001 then
                  -- { message = "File is a CommonJS module; it may be converted to an ES module.", }
                  table.remove(result.diagnostics, idx)
                else
                  idx = idx + 1
                end
              end

              vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, config)
            end,
          },
        },
      },
    },
  },

  {
    "davidosomething/format-ts-errors.nvim",
    opts = {
      add_markdown = true,
      start_indent_level = 0,
    },
  },
}
