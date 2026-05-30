-- This file configures the 'sourcekit' language server.
-- Source: https://github.com/swiftlang/sourcekit-lsp
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`. The table here
-- is MERGED on top of the defaults shipped by 'nvim-lspconfig' (see its
-- 'lsp/sourcekit.lua'), so `cmd`, `filetypes`, `root_dir`, and capabilities are
-- inherited and only need to be set here to override them.
--
-- Requires `sourcekit-lsp` on `$PATH`. On macOS it ships with the Xcode / Swift
-- toolchain (`/usr/bin/sourcekit-lsp`, or `xcrun --find sourcekit-lsp`). On Linux
-- it comes with the Swift toolchain from https://www.swift.org/install/.
--
-- NOTE: the shipped config also attaches to C/C++/Objective-C buffers. If you'd
-- rather scope it to Swift only, uncomment the `filetypes` line below.
--
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
return {
  -- filetypes = { 'swift' },
  on_attach = function(client, buf_id)
    -- Reduce very long list of triggers for better 'mini.completion' experience
    if client.server_capabilities.completionProvider then
      client.server_capabilities.completionProvider.triggerCharacters = { ".", "(", ":" }
    end

    -- Use this function to define buffer-local mappings and behavior that depend
    -- on attached client or only makes sense if there is language server attached.
  end,
}
