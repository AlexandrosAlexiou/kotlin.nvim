---@mod kotlin.dap Debugging through kotlin-lsp's bundled DAP server
---
--- Two entry points:
--- - attach (`:KotlinDebug [port]`): connect to a JVM started with JDWP.
--- - launch (`:KotlinRunMain`, `:KotlinDebugMain`, run/debug code lenses,
---   `dap.configurations.kotlin`, `.vscode/launch.json`): a launch
---   configuration only has to name `mainClass`. Everything else is resolved
---   from the project model in the adapter's `enrich_config` hook, exactly as
---   the VS Code extension resolves its configurations before the adapter
---   sees them (kotlin-lsp v263.4702.0+).
---
--- The adapter is a TCP server the LSP starts on demand (`start_debug_server`).

local M = {}

local adapter_registered = false

--- Default JDWP port used by Gradle (--debug-jvm) and Maven (-Dmaven.surefire.debug)
local DEFAULT_JDWP_PORT = 5005

--- Timeout (ms) for the LSP start_debug_server request.
local DEBUG_SERVER_TIMEOUT_MS = 10000

--- Timeout (ms) for the launch-resolution commands (matches the VS Code client).
local RESOLVE_TIMEOUT_MS = 30000

--- Where a launched program's output goes: "integratedTerminal" (DAP
--- runInTerminal, nvim-dap opens a terminal split), "internalConsole" (adapter
--- spawns the process and streams to the REPL) or "externalTerminal".
M.DEFAULT_CONSOLE = "integratedTerminal"

--- Configuration types the VS Code extension writes to launch.json. All of
--- them use this adapter; the Gradle one defaults to `launcher = "gradle"`.
M.VSCODE_TYPES = { "intellij_jvm", "intellij_gradle", "intellij_debugger" }

--- Build tools whose own launch the server can drive.
local BUILD_TOOL_LAUNCHERS = { gradle = true }

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

-- workspace/executeCommand with a timeout; `cb(err, result)`.
local function exec(client, command, arguments, cb)
  local done = false
  client:request("workspace/executeCommand", { command = command, arguments = arguments }, function(err, result)
    if done then
      return
    end
    done = true
    cb(err and (err.message or vim.inspect(err)) or nil, result)
  end, 0)
  vim.defer_fn(function()
    if not done then
      done = true
      cb(command .. " timed out after " .. RESOLVE_TIMEOUT_MS .. "ms")
    end
  end, RESOLVE_TIMEOUT_MS)
end

-- Run `build.command` in `build.cwd`, streaming output to the build log, then
-- `on_done(ok)`.
local function run_build(build, on_done)
  local intellij = require("kotlin.intellij")
  intellij.append_build_log("== " .. table.concat(build.command, " ") .. " ==")
  notify("building with " .. (build.tool or build.command[1]) .. "...", vim.log.levels.INFO)
  local function on_output(_, data)
    if data and data ~= "" then
      vim.schedule(function()
        intellij.append_build_log(data)
      end)
    end
  end
  local ok, err = pcall(vim.system, build.command, {
    cwd = build.cwd,
    text = true,
    stdout = on_output,
    stderr = on_output,
  }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        on_done(true)
      else
        notify(("build failed (exit %d). See :KotlinBuildLog"):format(result.code))
        intellij.open_build_log()
        on_done(false)
      end
    end)
  end)
  if not ok then
    notify("could not start the build: " .. tostring(err))
    on_done(false)
  end
end

--- Fill in what a launch configuration leaves out, from the project model.
--- Mirrors the VS Code extension's launch resolution (dap.ts):
---
---   file      -> intellij.java.resolveClassDocument { fqn } when absent
---   launcher = "auto" (the Run/Debug lens)
---             -> intellij.java.resolveBuildToolLaunch { uri, mainClass };
---                through the build tool when it can run the module
---                (Gradle), otherwise a plain JVM launch.
---   launcher = "gradle" (default for type intellij_gradle)
---             -> buildToolTarget for the adapter's Gradle command and
---                classPaths as the session's breakpoint scope.
---   launcher = "jvm" (default for every other type)
---             -> intellij.java.resolveBuildCommand { uri }, run first when
---                `dap.build_before_run` / `config.build` allow it
---             -> intellij.java.resolveLaunch { uri, cwd, overrides }:
---                javaExec, classPaths, modulePaths, moduleName,
---                moduleContentPaths, cwd in one answer.
---
--- Called by nvim-dap through the adapter's enrich_config hook. Not calling
--- on_config aborts the session, which is what happens on resolution errors.
---@param config table
---@param on_config fun(config: table)
function M.enrich_config(config, on_config)
  if config.request ~= "launch" then
    on_config(config)
    return
  end

  local client = get_client(vim.api.nvim_get_current_buf())
  if not client then
    notify("Kotlin LSP not running, cannot resolve the launch configuration")
    return
  end
  if not config.mainClass or config.mainClass == "" then
    notify('launch configurations require "mainClass"')
    return
  end

  local function fail(msg)
    notify("cannot start: " .. msg)
  end

  local function finish()
    config.console = config.console or options.console or M.DEFAULT_CONSOLE
    on_config(config)
  end

  -- Gradle launch: the adapter runs Gradle, which compiles and runs the module;
  -- the session is scoped to the module's classpath.
  local function apply_build_tool_launch(uri, response)
    config.launcher = response.tool
    config.buildToolTarget = {
      uri = uri,
      moduleName = response.moduleName,
      projectPath = config.projectPath,
      sourceSet = config.sourceSet,
      toolArgs = non_empty(config.gradleArgs),
    }
    config.classPaths = non_empty(response.scopeClassPaths)
    finish()
  end

  local function resolve_build_tool(uri, on_done)
    exec(client, "intellij.java.resolveBuildToolLaunch", { { uri = uri, mainClass = config.mainClass } }, on_done)
  end

  -- JVM launch: everything `java` needs, resolved in one request. The server
  -- merges the configuration's own values (`overrides`) itself.
  local function resolve_jvm(uri)
    config.launcher = "jvm"
    local overrides = {
      classPaths = non_empty(config.classPaths),
      modulePaths = non_empty(config.modulePaths),
      moduleName = config.moduleName,
      javaExec = config.javaExec,
    }
    if next(overrides) == nil then
      overrides = vim.empty_dict()
    end
    exec(
      client,
      "intellij.java.resolveLaunch",
      { { uri = uri, cwd = config.cwd, overrides = overrides } },
      function(err, paths)
        if err then
          fail("intellij.java.resolveLaunch failed: " .. err)
          return
        end
        paths = type(paths) == "table" and paths or {}
        config.classPaths = non_empty(paths.classpath)
        -- A JPMS launch carries the module path and the owning module, so the
        -- main class runs as `-m moduleName/mainClass`.
        config.modulePaths = non_empty(paths.modulePath)
        if paths.moduleName then
          config.moduleName = paths.moduleName
        end
        -- Output roots the adapter patches into the module with --patch-module.
        config.moduleContentPaths = non_empty(paths.moduleContentPaths)
        -- The module's directory unless the config named one; without either
        -- the program inherits the server's cwd.
        if paths.workingDirectory then
          config.cwd = paths.workingDirectory
        end
        if paths.javaExec then
          config.javaExec = paths.javaExec
        end
        finish()
      end
    )
  end

  -- Compile first (whatever tool the server names), then launch. Nothing to
  -- build, or no way to ask, launches what is already compiled.
  local function build_then_jvm(uri)
    local wanted = options.build_before_run ~= false
    if config.build == false or (config.build == nil and not wanted) then
      resolve_jvm(uri)
      return
    end
    exec(client, "intellij.java.resolveBuildCommand", { { uri = uri } }, function(err, resolved)
      if err then
        notify("build skipped, intellij.java.resolveBuildCommand failed: " .. err, vim.log.levels.WARN)
        resolve_jvm(uri)
        return
      end
      if
        type(resolved) ~= "table"
        or not resolved.supported
        or type(resolved.command) ~= "table"
        or #resolved.command == 0
      then
        resolve_jvm(uri)
        return
      end
      run_build({ tool = resolved.tool, command = resolved.command, cwd = resolved.cwd }, function(ok)
        if ok then
          resolve_jvm(uri)
        end
      end)
    end)
  end

  local function resolve_from(uri)
    local launcher = config.launcher
    if launcher == nil then
      launcher = config.type == "intellij_gradle" and "gradle" or "jvm"
    end
    if launcher == "jvm" then
      build_then_jvm(uri)
    elseif BUILD_TOOL_LAUNCHERS[launcher] then
      resolve_build_tool(uri, function(err, response)
        if err then
          fail("intellij.java.resolveBuildToolLaunch failed: " .. err)
        elseif type(response) ~= "table" or response.tool == nil then
          fail(('no build tool can launch "%s"; use launcher = "jvm"'):format(config.mainClass))
        elseif response.tool ~= launcher then
          fail(('"%s" is launched by %s, not %s'):format(config.mainClass, response.tool, launcher))
        else
          apply_build_tool_launch(uri, response)
        end
      end)
    elseif launcher == "auto" then
      -- Prefer the build tool's own launch when one exists; a failure to ask
      -- falls back to a JVM launch, which reports properly.
      resolve_build_tool(uri, function(err, response)
        if not err and type(response) == "table" and BUILD_TOOL_LAUNCHERS[response.tool or ""] then
          apply_build_tool_launch(uri, response)
        else
          build_then_jvm(uri)
        end
      end)
    else
      fail(('unknown launcher "%s" (expected "auto", "jvm" or "gradle")'):format(tostring(launcher)))
    end
  end

  if type(config.file) == "string" and config.file ~= "" and not config.file:find("${", 1, true) then
    resolve_from(vim.uri_from_fname(vim.fn.fnamemodify(config.file, ":p")))
    return
  end

  exec(client, "intellij.java.resolveClassDocument", { { fqn = config.mainClass } }, function(err, result)
    local uri = type(result) == "table" and result.uri or nil
    if err or not uri then
      fail(("no source file for %s%s"):format(config.mainClass, err and (": " .. err) or ""))
      return
    end
    resolve_from(uri)
  end)
end

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
            -- Resolve classpath, cwd and JDK from the project model before the
            -- session starts, like the VS Code extension does.
            enrich_config = M.enrich_config,
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
  listeners_set = true
end

local function short_name(main_class)
  return main_class:match("([^.]+)$") or main_class
end

--- Launch (run or debug) a `main` class. Fields other than `mainClass` are
--- optional; everything the JVM needs is resolved by enrich_config.
--- `launcher`: "auto" (default: the build tool when it can run the module,
--- like the run lens), "gradle" or "jvm".
---@param target { mainClass: string, uri?: string, file?: string, noDebug?: boolean, launcher?: "auto"|"gradle"|"jvm", args?: string[], vmArgs?: string[], env?: table<string,string>, cwd?: string, console?: string, build?: boolean, projectPath?: string, sourceSet?: string, gradleArgs?: string[] }
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
    noDebug = target.noDebug == true,
    launcher = target.launcher or "auto",
    args = non_empty(target.args),
    vmArgs = non_empty(target.vmArgs),
    env = target.env,
    cwd = target.cwd,
    console = target.console,
    build = target.build,
    projectPath = target.projectPath,
    sourceSet = target.sourceSet,
    gradleArgs = non_empty(target.gradleArgs),
  })
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
    M.run_main({ mainClass = t.mainClass, uri = t.uri, noDebug = no_debug, args = fargs })
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
--- buffers. Every field except `mainClass` is resolved from the project model.
local function default_configurations()
  return {
    {
      type = "kotlin",
      request = "launch",
      name = "Launch main class",
      mainClass = function()
        return vim.fn.input("Main class: ")
      end,
      launcher = "auto",
    },
    {
      type = "kotlin",
      request = "launch",
      name = "Launch main class (plain JVM)",
      mainClass = function()
        return vim.fn.input("Main class: ")
      end,
      launcher = "jvm",
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
---@param opts? table plugin options (`dap.console`, `dap.build_before_run`, `dap.configurations`)
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
