return {
  {
    "saghen/blink.cmp",

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      sources = {
        default = function()
          return { "snippets", "lsp", "path" }
        end,
        -- Filter keywords
        transform_items = function(_, items)
          return vim.tbl_filter(function(item)
            return item.kind ~= require("blink.cmp.types").CompletionItemKind.Keyword
          end, items)
        end,
      },
      enabled = function()
        -- Disable for markdown or text filetypes
        local disabled_filetypes = {
          "markdown",
          "text",
          "snacks_picker_input",
        }

        return not vim.tbl_contains(disabled_filetypes, vim.bo.filetype)
      end,
      keymap = {
        preset = "default",

        ["<Tab>"] = { "fallback" },
        ["<C-e>"] = { "hide" },
        ["<C-l>"] = { "select_and_accept" },
        ["<C-;>"] = {
          LazyVim.cmp.map({ "snippet_forward", "ai_accept" }),
        },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<C-j>"] = { "select_next", "fallback" },

        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      },
      completion = {
        documentation = {
          window = {
            border = "rounded",
          },
        },
      },
      signature = {
        window = {
          border = "rounded",
        },
      },
    },
  },
}
