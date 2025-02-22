return {
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")
      if dap.adapters["pwa-node"] then
        require("dap").adapters["pwa-node"] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = {
            command = "vscode-js-debug",
            args = {
              "${port}",
              -- explicit host bind, otherwise it may bind to IPv6 address
              --"0.0.0.0",
            },
          },
        }

        local js_filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" }

        for _, language in ipairs(js_filetypes) do
          dap.configurations[language] = {
            {
              type = "pwa-node",
              request = "launch",
              name = "Launch file",
              program = "${file}",
              cwd = "${workspaceFolder}",
            },
            {
              type = "pwa-node",
              request = "attach",
              name = "Attach (port)",
              host = "localhost",
              port = 9229,
              cwd = "${workspaceFolder}",
            },
            {
              type = "pwa-node",
              request = "attach",
              name = "Attach (process)",
              processId = require("dap.utils").pick_process,
              cwd = "${workspaceFolder}",
            },
          }
        end
      end
    end,
  },
}
