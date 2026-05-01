local M = {}

local adapter_registered = false

--- Default JDWP port used by Gradle (--debug-jvm) and Maven (-Dmaven.surefire.debug)
local DEFAULT_JDWP_PORT = 5005

--- Ensure the Kotlin DAP adapter is registered with nvim-dap.
--- Called lazily on first debug session to avoid load-order issues.
local function ensure_adapter()
  if adapter_registered then
    return true
  end

  local ok, dap = pcall(require, "dap")
  if not ok then
    vim.notify("nvim-dap is required for debugging. Install mfussenegger/nvim-dap", vim.log.levels.ERROR)
    return false
  end

  -- Register adapter as a function for dynamic port resolution.
  -- Only set if not already configured by the user.
  if not dap.adapters.kotlin then
    dap.adapters.kotlin = function(cb)
      local clients = vim.lsp.get_clients({ name = "kotlin_ls" })
      if #clients == 0 then
        vim.notify("Kotlin LSP not running. Open a Kotlin file first.", vim.log.levels.ERROR)
        return
      end

      local client = clients[1]
      local cwd = vim.fn.getcwd()
      local workspace_uri = vim.uri_from_fname(cwd)

      -- Ask kotlin-lsp to spin up a DAP server and return its port
      client:request("workspace/executeCommand", {
        command = "start_debug_server",
        arguments = { workspace_uri },
      }, function(err, result)
        if err then
          vim.notify("Failed to start debug server: " .. vim.inspect(err), vim.log.levels.ERROR)
          return
        end

        local port = tonumber(result)
        if not port then
          vim.notify("Invalid debug server port: " .. vim.inspect(result), vim.log.levels.ERROR)
          return
        end

        vim.schedule(function()
          cb({
            type = "server",
            host = "127.0.0.1",
            port = port,
            id = "intellij_debugger",
          })
        end)
      end)
    end
  end

  adapter_registered = true
  return true
end

--- Register the :KotlinDebug command.
--- The DAP adapter itself is registered lazily on first use.
function M.setup()
  vim.api.nvim_create_user_command("KotlinDebug", function(opts)
    local jdwp_port = nil
    if opts.args and opts.args ~= "" then
      jdwp_port = tonumber(opts.args)
      if not jdwp_port then
        vim.notify("Invalid port: " .. opts.args, vim.log.levels.ERROR)
        return
      end
    end
    M.start({ port = jdwp_port })
  end, {
    nargs = "?",
    desc = "Attach debugger to a Kotlin/JVM process (optionally specify JDWP port, default 5005)",
  })
end

--- Prompt the user for the JDWP port, then start the debug session.
---@param config? table DAP configuration overrides (port = JDWP port to attach to)
function M.start(config)
  if not ensure_adapter() then
    return
  end

  config = config or {}
  local jdwp_port = config.port

  local function run_with_port(port)
    local dap = require("dap")
    local dap_config = {
      type = "kotlin",
      request = "attach",
      name = "Attach Kotlin Program",
      port = port,
    }
    dap.run(dap_config)
  end

  if jdwp_port then
    run_with_port(jdwp_port)
  else
    vim.ui.input({
      prompt = "JDWP debug port (default " .. DEFAULT_JDWP_PORT .. "): ",
    }, function(input)
      if input == nil then
        return -- cancelled
      end
      local port = DEFAULT_JDWP_PORT
      if input ~= "" then
        port = tonumber(input)
        if not port then
          vim.notify("Invalid port: " .. input, vim.log.levels.ERROR)
          return
        end
      end
      run_with_port(port)
    end)
  end
end

return M
