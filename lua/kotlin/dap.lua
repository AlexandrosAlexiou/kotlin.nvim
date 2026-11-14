---@mod kotlin.dap Debugging through kotlin-lsp's bundled DAP server
---
--- Three entry points:
--- - attach (`:KotlinDebug [port]`): connect to a JVM started with JDWP.
--- - launch (`:KotlinRunMain`, `:KotlinDebugMain`, run/debug code lenses,
---   `dap.configurations.kotlin`, `.vscode/launch.json`): a launch
---   configuration only has to name `mainClass`. The server (v271.2085.0+)
---   finds its module, builds it and runs the program itself.
--- - tests (Run Test / Debug Test code lenses): the server names the test
---   runner process, which is launched like a main class.
---
--- The adapter is a TCP server the LSP starts on demand (`start_debug_server`).

local M = {}

local adapter_registered = false

--- Default JDWP port used by Gradle (--debug-jvm) and Maven (-Dmaven.surefire.debug)
local DEFAULT_JDWP_PORT = 5005

--- Timeout (ms) for the LSP start_debug_server request.
local DEBUG_SERVER_TIMEOUT_MS = 10000

--- The server runs every program itself and streams its output as DAP
--- `output` events, which nvim-dap prints in its REPL. "integratedTerminal"
--- opens the REPL when output arrives; "internalConsole" leaves that to you.
M.DEFAULT_CONSOLE = "integratedTerminal"

--- Configuration types the VS Code extension writes to launch.json. All of
--- them use this adapter; the Gradle one defaults to `launcher = "gradle"`.
M.VSCODE_TYPES = { "intellij_jvm", "intellij_gradle", "intellij_debugger" }

--- `launcher` -> the `tool` launch argument: Gradle runs the module itself,
--- "java" is a plain JVM the server builds the module for first.
local TOOL_BY_LAUNCHER = { gradle = "gradle", jvm = "java" }

local options = {}

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

local function get_client(bufnr)
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })
  if #clients == 0 then
    clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
  end
  return clients[1]
end

local function notify(msg, level)
  vim.notify("kotlin.nvim: " .. msg, level or vim.log.levels.ERROR)
end

--- A list for the wire, or nil when there is nothing in it. An empty Lua table
--- encodes as a JSON object, which the server's list fields reject; leaving
--- the key out is what "no value" means to it.
local function non_empty(list)
  if type(list) == "table" and #list > 0 then
    return list
  end
  return nil
end

--- Put a launch configuration into the adapter's vocabulary, as the VS Code
--- extension does (dap.ts). Nothing is asked of the server: it resolves the
--- module, class path, JDK and working directory from the launch itself.
---
---   launcher = "gradle" (default for type intellij_gradle and for a lens on a
---              Gradle module) -> tool "gradle", `gradleArgs` as `toolArgs`
---   launcher = "jvm"    (default otherwise) -> tool "java"
---
--- Called by nvim-dap through the adapter's enrich_config hook. Not calling
--- on_config aborts the session.
---@param config table
---@param on_config fun(config: table)
function M.enrich_config(config, on_config)
  if config.request ~= "launch" then
    on_config(config)
    return
  end
  if not config.mainClass or config.mainClass == "" then
    notify('launch configurations require "mainClass"')
    return
  end
  local launcher = config.launcher
  if launcher == nil or launcher == "auto" then
    -- `tool` is the module's build tool as the run lens names it.
    launcher = (config.type == "intellij_gradle" or config.tool == "gradle") and "gradle" or "jvm"
  end
  if not TOOL_BY_LAUNCHER[launcher] then
    notify(('cannot start: unknown launcher "%s" (expected "auto", "jvm" or "gradle")'):format(tostring(launcher)))
    return
  end
  config.tool = TOOL_BY_LAUNCHER[launcher]
  config.toolArgs = non_empty(config.gradleArgs)
  config.console = config.console or options.console or M.DEFAULT_CONSOLE
  on_config(config)
end

-- TeamCity service message escapes: |n and |r, every other |x stands for x.
local TEAMCITY_ESCAPES = { n = "\n", r = "\r" }

-- Value of attribute `key` in a `##teamcity[kind key='value' ...]` message.
-- shortcut: |0xNNNN unicode escapes come through as text, decode them if a test name ever needs it
local function teamcity_attr(message, key)
  local _, i = message:find(" " .. key .. "='", 1, true)
  local out = {}
  while i and i < #message do
    i = i + 1
    local c = message:sub(i, i)
    if c == "'" then
      break
    elseif c == "|" then
      i = i + 1
      c = message:sub(i, i)
      c = TEAMCITY_ESCAPES[c] or c
    end
    out[#out + 1] = c
  end
  return table.concat(out)
end

--- The test runner reports through TeamCity service messages on stdout. Turn
--- the results into readable lines, drop the bookkeeping and pass the tests'
--- own output through. `failed` remembers a failure until its testFinished.
---@param output string one DAP output chunk
---@param failed table<string, boolean>
---@return string
function M.test_output(output, failed)
  local kind = output:match("^##teamcity%[(%a+)")
  if not kind then
    return output
  end
  local name = teamcity_attr(output, "name")
  if kind == "testFailed" then
    failed[name] = true
    -- A failed comparison carries its two sides apart from the message.
    local expected, actual = teamcity_attr(output, "expected"), teamcity_attr(output, "actual")
    local compared = (expected .. actual) ~= "" and ("expected: <%s> but was: <%s>"):format(expected, actual)
      or ""
    local details = teamcity_attr(output, "details"):gsub("^\n", ""):gsub("\n+$", "")
    return ("✗ %s\n%s%s\n%s\n"):format(name, teamcity_attr(output, "message"), compared, details)
  elseif kind == "testIgnored" then
    return ("- %s (ignored)\n"):format(name)
  elseif kind == "testFinished" then
    if not failed[name] then
      return ("✓ %s (%s ms)\n"):format(name, teamcity_attr(output, "duration"))
    end
    failed[name] = nil
  end
  return ""
end

assert(M.test_output("##teamcity[testFailed name='a|'b()' message='x|ny' details='|[d|]']\n", {}) == "✗ a'b()\nx\ny\n[d]\n")

--- Ensure the Kotlin DAP adapter is registered with nvim-dap.
--- Called lazily on first debug session to avoid load-order issues.
local function ensure_adapter()
  if adapter_registered then
    return true
  end

  local ok, dap = pcall(require, "dap")
  if not ok then
    notify("nvim-dap is required for debugging. Install mfussenegger/nvim-dap")
    return false
  end

  -- Register adapter as a function for dynamic port resolution.
  -- Only set if not already configured by the user.
  if not dap.adapters.kotlin then
    dap.adapters.kotlin = function(cb)
      local client = get_client(vim.api.nvim_get_current_buf())
      if not client then
        notify("Kotlin LSP not running. Open a Kotlin file first.")
        return
      end

      local workspace_uri = vim.uri_from_fname(client.root_dir or vim.fn.getcwd())

      notify("requesting debug server from kotlin-lsp...", vim.log.levels.INFO)

      local request_done = false

      -- Ask kotlin-lsp to spin up a DAP server and return its port
      client:request("workspace/executeCommand", {
        command = "start_debug_server",
        arguments = { workspace_uri },
      }, function(err, result)
        request_done = true

        if err then
          vim.schedule(function()
            notify("failed to start debug server: " .. vim.inspect(err))
          end)
          return
        end

        local port = tonumber(result)
        if not port then
          vim.schedule(function()
            notify("invalid debug server port from kotlin-lsp: " .. vim.inspect(result))
          end)
          return
        end

        vim.schedule(function()
          notify("debug server listening on port " .. port, vim.log.levels.INFO)
          cb({
            type = "server",
            host = "127.0.0.1",
            port = port,
            -- adapterID sent in the DAP initialize request. `intellij_debugger`
            -- is the deprecated alias.
            id = "intellij_jvm",
            enrich_config = M.enrich_config,
            -- A debug launch is answered only once the server has built the
            -- module; nvim-dap's 4 s default calls that an unresponsive adapter.
            options = { initialize_timeout_sec = 600 },
          })
        end)
      end)

      vim.defer_fn(function()
        if not request_done then
          notify(
            "debug server request timed out after " .. (DEBUG_SERVER_TIMEOUT_MS / 1000) .. "s. Is kotlin-lsp healthy?"
          )
        end
      end, DEBUG_SERVER_TIMEOUT_MS)
    end
  end

  -- launch.json written for the VS Code extension names these types; route
  -- them to the same adapter so the file works unchanged.
  for _, t in ipairs(M.VSCODE_TYPES) do
    if not dap.adapters[t] then
      dap.adapters[t] = dap.adapters.kotlin
    end
  end

  adapter_registered = true
  return true
end

local listeners_set = false

local function ensure_listeners()
  if listeners_set then
    return
  end
  local dap = require("dap")
  dap.listeners.after.event_initialized["kotlin_nvim"] = function()
    notify("debug session started", vim.log.levels.INFO)
  end
  dap.listeners.after.event_terminated["kotlin_nvim"] = function()
    notify("debug session ended", vim.log.levels.INFO)
  end
  dap.listeners.after.disconnect["kotlin_nvim"] = function()
    notify("debugger disconnected", vim.log.levels.INFO)
  end
  local last_session, failed
  dap.listeners.before.event_output["kotlin_nvim"] = function(session, body)
    local config = session.config
    if config.type ~= "kotlin" and not vim.tbl_contains(M.VSCODE_TYPES, config.type) then
      return
    end
    local first = last_session ~= session
    last_session = session
    if first then
      failed = {}
    end
    if config.kotlinTest and body.output then
      body.output = M.test_output(body.output, failed)
    end
    -- Open the REPL on a session's first output, unless a window (nvim-dap-ui,
    -- ...) already shows it or the configuration says "internalConsole".
    if first and config.console ~= "internalConsole" and body.category ~= "telemetry" then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "dap-repl" then
          return
        end
      end
      dap.repl.open({ height = 12 })
    end
  end
  listeners_set = true
end

local function short_name(main_class)
  return main_class:match("([^.]+)$") or main_class
end

--- Launch (run or debug) a `main` class. Only `mainClass` is required; the
--- server resolves and builds everything else.
--- `launcher`: "gradle" or "jvm"; by default Gradle for a Gradle module (`tool`,
--- as the run lens names it) and a plain JVM otherwise.
---@param target { mainClass: string, uri?: string, file?: string, tool?: string, noDebug?: boolean, launcher?: "auto"|"gradle"|"jvm", args?: string[], vmArgs?: string[], env?: table<string,string>, cwd?: string, console?: string, projectPath?: string, sourceSet?: string, gradleArgs?: string[], stepFilters?: table }
function M.run_main(target)
  if not ensure_adapter() then
    return
  end
  if type(target) ~= "table" or not target.mainClass then
    notify("run_main needs a mainClass")
    return
  end
  ensure_listeners()

  local file = target.file
  if not file and target.uri and vim.startswith(target.uri, "file://") then
    file = vim.uri_to_fname(target.uri)
  end

  require("dap").run({
    type = "kotlin",
    request = "launch",
    name = (target.noDebug and "Run " or "Debug ") .. short_name(target.mainClass),
    mainClass = target.mainClass,
    file = file,
    tool = target.tool,
    noDebug = target.noDebug == true,
    launcher = target.launcher,
    args = non_empty(target.args),
    vmArgs = non_empty(target.vmArgs),
    env = target.env,
    cwd = target.cwd,
    console = target.console,
    projectPath = target.projectPath,
    sourceSet = target.sourceSet,
    gradleArgs = non_empty(target.gradleArgs),
    stepFilters = target.stepFilters,
  })
end

--- Run or debug a test class or method: the Run Test / Debug Test lenses
--- (v271.2085.0+). The server names the runner process and its jars; it runs
--- on the class path of the test's module, which the server builds first.
---@param target { testId: string, uri: string, noDebug?: boolean }
function M.run_test(target)
  if not ensure_adapter() then
    return
  end
  local client = get_client(vim.api.nvim_get_current_buf())
  if not client or type(target) ~= "table" or not target.testId then
    notify("cannot run the test: " .. (client and "malformed test lens" or "Kotlin LSP not running"))
    return
  end
  ensure_listeners()
  client:request("workspace/executeCommand", {
    command = "intellij.jvm.resolveTestLaunch",
    arguments = { { testIds = { target.testId }, uniqueIds = {}, tags = {} } },
  }, function(err, launches)
    -- shortcut: one runner process per run; start the others too if a single test id ever resolves to several
    local launch = type(launches) == "table" and launches[1]
    if err or not launch then
      notify("cannot run the test: " .. (err and err.message or "the server found no way to run it"))
      return
    end
    require("dap").run({
      type = "kotlin",
      request = "launch",
      name = (target.noDebug and "Run " or "Debug ") .. short_name(target.testId),
      mainClass = launch.mainClass,
      file = type(launch.file) == "string" and launch.file or vim.uri_to_fname(target.uri),
      args = launch.args,
      additionalClassPaths = launch.runtimeClasspath,
      additionalModulePaths = non_empty(launch.runtimeModulePath),
      noDebug = target.noDebug == true,
      launcher = "jvm",
      kotlinTest = true,
    })
  end)
end

-- Pick a main class in the current buffer (from the run lenses) and launch it.
local function run_current(no_debug, fargs)
  if not ensure_adapter() then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local targets = require("kotlin.codelens").main_targets(bufnr)
  if #targets == 0 then
    notify(
      "no runnable main function found in this buffer (is the project imported and code_lens enabled?)",
      vim.log.levels.WARN
    )
    return
  end
  local function go(t)
    M.run_main({ mainClass = t.mainClass, uri = t.uri, tool = t.tool, noDebug = no_debug, args = fargs })
  end
  if #targets == 1 then
    go(targets[1])
    return
  end
  vim.ui.select(targets, {
    prompt = "Main class:",
    format_item = function(t)
      return t.mainClass
    end,
  }, function(choice)
    if choice then
      go(choice)
    end
  end)
end

--- Default nvim-dap configurations for `dap.continue()` in Kotlin (and Java)
--- buffers. Every field except `mainClass` is resolved by the server.
local function default_configurations()
  return {
    {
      type = "kotlin",
      request = "launch",
      name = "Launch main class",
      mainClass = function()
        return vim.fn.input("Main class: ")
      end,
    },
    {
      type = "kotlin",
      request = "launch",
      name = "Launch main class (Gradle)",
      mainClass = function()
        return vim.fn.input("Main class: ")
      end,
      launcher = "gradle",
    },
    {
      type = "kotlin",
      request = "attach",
      name = "Attach to JVM",
      port = function()
        return tonumber(vim.fn.input("JDWP port: ", tostring(DEFAULT_JDWP_PORT))) or DEFAULT_JDWP_PORT
      end,
    },
  }
end

--- Register the debug commands. The DAP adapter itself is registered lazily.
---@param opts? table plugin options (`dap.console`, `dap.configurations`)
function M.setup(opts)
  options = (opts and opts.dap) or {}

  vim.api.nvim_create_user_command("KotlinDebug", function(cmd)
    local jdwp_port = nil
    if cmd.args and cmd.args ~= "" then
      jdwp_port = tonumber(cmd.args)
      if not jdwp_port then
        notify("invalid port: " .. cmd.args)
        return
      end
    end
    M.start({ port = jdwp_port })
  end, {
    nargs = "?",
    desc = "Attach debugger to a Kotlin/JVM process (optionally specify JDWP port, default 5005)",
  })

  vim.api.nvim_create_user_command("KotlinRunMain", function(cmd)
    run_current(true, cmd.fargs)
  end, {
    nargs = "*",
    desc = "Run the main function in the current buffer (program args optional)",
  })

  vim.api.nvim_create_user_command("KotlinDebugMain", function(cmd)
    run_current(false, cmd.fargs)
  end, {
    nargs = "*",
    desc = "Debug the main function in the current buffer (program args optional)",
  })

  -- Default configurations for dap.continue(); opt out with
  -- dap.configurations = false.
  if options.configurations ~= false then
    local ok, dap = pcall(require, "dap")
    if ok then
      for _, ft in ipairs({ "kotlin", "java" }) do
        dap.configurations[ft] = dap.configurations[ft] or {}
        for _, config in ipairs(default_configurations()) do
          local exists = false
          for _, existing in ipairs(dap.configurations[ft]) do
            if existing.name == config.name then
              exists = true
            end
          end
          if not exists then
            table.insert(dap.configurations[ft], config)
          end
        end
      end
    end
  end
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
    notify("checking JDWP port " .. port .. "...", vim.log.levels.INFO)

    if not is_port_open("127.0.0.1", port) then
      notify(
        "nothing is listening on port "
          .. port
          .. ". Start your app with JDWP debugging enabled first.\n"
          .. "  Gradle:  ./gradlew run --debug-jvm\n"
          .. "  Maven:   mvn test -Dmaven.surefire.debug\n"
          .. "  Manual:  java -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=*:"
          .. port
          .. " ..."
      )
      return
    end

    notify("JDWP port " .. port .. " is open, starting debug session...", vim.log.levels.INFO)

    ensure_listeners()
    require("dap").run({
      type = "kotlin",
      request = "attach",
      name = "Attach Kotlin Program",
      port = port,
    })
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
      ---@type integer?
      local port = DEFAULT_JDWP_PORT
      if input ~= "" then
        port = tonumber(input)
        if not port then
          notify("invalid port: " .. input)
          return
        end
      end
      run_with_port(port)
    end)
  end
end

return M
