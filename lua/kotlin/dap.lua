local M = {}

local adapter_registered = false

--- Default JDWP port used by Gradle (--debug-jvm) and Maven (-Dmaven.surefire.debug)
local DEFAULT_JDWP_PORT = 5005

--- Timeout (ms) for the LSP start_debug_server request.
local DEBUG_SERVER_TIMEOUT_MS = 10000

--- Check whether a TCP port is accepting connections.
--- Returns true if something is listening, false otherwise.
---@param host string
---@param port number
---@return boolean
local function is_port_open(host, port)
  local uv = vim.uv or vim.loop
  local tcp = uv.new_tcp()
  local connected = false
  local done = false

  tcp:connect(host, port, function(err)
    if not err then
      connected = true
    end
    done = true
    if not tcp:is_closing() then
      tcp:close()
    end
  end)

  -- Block for up to 2 seconds waiting for the connection attempt
  local deadline = uv.now() + 2000
  while not done and uv.now() < deadline do
    uv.run("once")
  end

  if not done then
    -- Timed out
    if not tcp:is_closing() then
      tcp:close()
    end
    return false
  end

  return connected
end

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
        vim.notify("kotlin.nvim: Kotlin LSP not running. Open a Kotlin file first.", vim.log.levels.ERROR)
        return
      end

      local client = clients[1]
      local cwd = vim.fn.getcwd()
      local workspace_uri = vim.uri_from_fname(cwd)

      vim.notify("kotlin.nvim: requesting debug server from kotlin-lsp...", vim.log.levels.INFO)

      local request_done = false

      -- Ask kotlin-lsp to spin up a DAP server and return its port
      client:request("workspace/executeCommand", {
        command = "start_debug_server",
        arguments = { workspace_uri },
      }, function(err, result)
        request_done = true

        if err then
          vim.schedule(function()
            vim.notify("kotlin.nvim: failed to start debug server: " .. vim.inspect(err), vim.log.levels.ERROR)
          end)
          return
        end

        local port = tonumber(result)
        if not port then
          vim.schedule(function()
            vim.notify(
              "kotlin.nvim: invalid debug server port from kotlin-lsp: " .. vim.inspect(result),
              vim.log.levels.ERROR
            )
          end)
          return
        end

        vim.schedule(function()
          vim.notify("kotlin.nvim: debug server listening on port " .. port, vim.log.levels.INFO)
          cb({
            type = "server",
            host = "127.0.0.1",
            port = port,
            id = "intellij_debugger",
          })
        end)
      end)

      vim.defer_fn(function()
        if not request_done then
          vim.notify(
            "kotlin.nvim: debug server request timed out after "
              .. (DEBUG_SERVER_TIMEOUT_MS / 1000)
              .. "s. Is kotlin-lsp healthy?",
            vim.log.levels.ERROR
          )
        end
      end, DEBUG_SERVER_TIMEOUT_MS)
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
        vim.notify("kotlin.nvim: invalid port: " .. opts.args, vim.log.levels.ERROR)
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
    -- Pre-flight: check if anything is listening on the JDWP port
    vim.notify("kotlin.nvim: checking JDWP port " .. port .. "...", vim.log.levels.INFO)

    if not is_port_open("127.0.0.1", port) then
      vim.notify(
        "kotlin.nvim: nothing is listening on port "
          .. port
          .. ". Start your app with JDWP debugging enabled first.\n"
          .. "  Gradle:  ./gradlew run --debug-jvm\n"
          .. "  Maven:   mvn test -Dmaven.surefire.debug\n"
          .. "  Manual:  java -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=*:"
          .. port
          .. " ...",
        vim.log.levels.ERROR
      )
      return
    end

    vim.notify("kotlin.nvim: JDWP port " .. port .. " is open, starting debug session...", vim.log.levels.INFO)

    local dap = require("dap")

    -- Listen for session events to provide feedback
    local session_listeners_set = false
    if not session_listeners_set then
      dap.listeners.after.event_initialized["kotlin_nvim"] = function()
        vim.notify("kotlin.nvim: debugger attached successfully", vim.log.levels.INFO)
      end
      dap.listeners.after.event_terminated["kotlin_nvim"] = function()
        vim.notify("kotlin.nvim: debug session ended", vim.log.levels.INFO)
      end
      dap.listeners.after.disconnect["kotlin_nvim"] = function()
        vim.notify("kotlin.nvim: debugger disconnected", vim.log.levels.INFO)
      end
      session_listeners_set = true
    end

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
          vim.notify("kotlin.nvim: invalid port: " .. input, vim.log.levels.ERROR)
          return
        end
      end
      run_with_port(port)
    end)
  end
end

return M
