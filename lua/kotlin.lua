local M = {}

function M.setup(opts)
  opts = opts or {}

  -- Register user commands eagerly so :KotlinHealth (and friends) are available
  -- even when LSP startup fails. The LSP itself is wired lazily on FileType.
  require("kotlin.commands").setup()
  require("kotlin.dap").setup()
  require("kotlin.file_templates").setup(opts)

  vim.api.nvim_create_user_command("KotlinCleanWorkspace", function()
    M.clean_workspace()
  end, { desc = "Clean Kotlin LSP workspace for current project" })

  -- Create an autocommand group for kotlin-lsp
  local group = vim.api.nvim_create_augroup("kotlin_lsp", { clear = true })

  -- Set up the autocmd to configure Kotlin LSP when a Kotlin file is opened
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "kotlin",
    callback = function()
      M.setup_kotlin_lsp(opts)
    end,
    group = group,
  })
end

function M.get_workspace_base_dir()
  local is_windows = vim.fn.has("win32") == 1

  if is_windows then
    -- Use %LOCALAPPDATA% on Windows
    local localappdata = os.getenv("LOCALAPPDATA")
    if localappdata then
      return localappdata .. "\\kotlin-lsp-workspaces"
    else
      -- Fallback to user profile
      local userprofile = os.getenv("USERPROFILE")
      return userprofile .. "\\AppData\\Local\\kotlin-lsp-workspaces"
    end
  else
    -- Use ~/.cache on Unix-like systems
    local home = os.getenv("HOME")
    return home .. "/.cache/kotlin-lsp-workspaces"
  end
end

function M.clean_workspace()
  local current_dir = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(current_dir, ":p:h:t")
  local workspace_base = M.get_workspace_base_dir()
  local is_windows = vim.fn.has("win32") == 1
  local workspace_dir = workspace_base .. (is_windows and "\\" or "/") .. project_name

  vim.notify("Cleaning workspace for " .. project_name, vim.log.levels.INFO)

  -- Stop existing Kotlin LSP clients
  for _, client in ipairs(vim.lsp.get_clients({ name = "kotlin_lsp" })) do
    vim.notify("Stopping Kotlin LSP...", vim.log.levels.INFO)
    vim.lsp.stop_client(client.id)
    vim.cmd("sleep 500m")
  end

  -- Remove workspace directory if it exists (plugin-managed state)
  if vim.fn.isdirectory(workspace_dir) == 1 then
    if is_windows then
      vim.fn.system('rmdir /s /q "' .. workspace_dir .. '"')
    else
      vim.fn.system("rm -rf " .. vim.fn.shellescape(workspace_dir))
    end
  end

  -- v262.4739.0+: intellij-server also writes to the JetBrains analyzer cache
  -- (RocksDB indexes, logs, etc.). Clean that too or stale locks will block restarts.
  local jetbrains_cache
  if is_windows then
    local localappdata = os.getenv("LOCALAPPDATA")
    jetbrains_cache = localappdata and (localappdata .. "\\JetBrains\\analyzer")
  elseif vim.fn.has("mac") == 1 then
    jetbrains_cache = os.getenv("HOME") .. "/Library/Caches/JetBrains/analyzer"
  else
    local xdg = os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")
    jetbrains_cache = xdg .. "/JetBrains/analyzer"
  end

  if jetbrains_cache and vim.fn.isdirectory(jetbrains_cache) == 1 then
    if is_windows then
      vim.fn.system('rmdir /s /q "' .. jetbrains_cache .. '"')
    else
      vim.fn.system("rm -rf " .. vim.fn.shellescape(jetbrains_cache))
    end
    vim.notify("Cleaned JetBrains analyzer cache: " .. jetbrains_cache, vim.log.levels.INFO)
  end

  vim.notify("Workspace cleaned. Ready to restart Kotlin LSP.", vim.log.levels.INFO)
end

function M.setup_kotlin_lsp(opts)
  -- Check for buffer-local disable flag
  if vim.b.disable_kotlin_lsp then
    return
  end

  opts = opts or {}
  local is_windows = vim.fn.has("win32") == 1

  -- Get current buffer's directory as starting point for root detection
  local buf_dir = vim.fn.expand("%:p:h")
  if buf_dir == "" or buf_dir == "." then
    buf_dir = vim.fn.getcwd()
  end

  -- Search upward from the buffer directory for marker/config files
  local function find_file_upward(filename, start_dir)
    local dir = start_dir
    while dir and dir ~= "" do
      local filepath = dir .. "/" .. filename
      if vim.fn.filereadable(filepath) == 1 then
        return filepath
      end
      local parent = vim.fn.fnamemodify(dir, ":h")
      if parent == dir then
        break
      end
      dir = parent
    end
    return nil
  end

  -- Check for marker file that disables Kotlin LSP
  if find_file_upward(".disable-kotlin-lsp", buf_dir) then
    return
  end

  local current_dir = vim.fn.getcwd()

  -- Check for project-specific configuration file
  local project_config_file = find_file_upward(".kotlin-lsp.lua", buf_dir) or (current_dir .. "/.kotlin-lsp.lua")
  if vim.fn.filereadable(project_config_file) == 1 then
    local ok, project_config = pcall(dofile, project_config_file)
    if ok and type(project_config) == "table" then
      -- Merge project config with global config (project config takes precedence)
      opts = vim.tbl_deep_extend("force", opts, project_config)
    else
      vim.notify(
        "Failed to load project config from .kotlin-lsp.lua: " .. tostring(project_config),
        vim.log.levels.WARN
      )
    end
  end

  local project_name = vim.fn.fnamemodify(current_dir, ":p:h:t")
  local workspace_base = M.get_workspace_base_dir()
  local workspace_dir = workspace_base .. (is_windows and "\\" or "/") .. project_name

  -- Create workspace directory
  vim.fn.mkdir(workspace_dir, "p")

  -- Find Kotlin LSP installation directory.
  -- v262.4739.0+ Mason packages put everything under a versioned subdirectory
  -- (e.g. kotlin-server-262.4739.0/) because the .sit/.tar.gz archive's root
  -- changed. Older builds extracted directly into the package root. Probe both.
  local kotlin_lsp_dir = nil

  local mason_package_dir = vim.fn.expand("$MASON/packages/kotlin-lsp")

  if vim.fn.isdirectory(mason_package_dir) == 1 then
    kotlin_lsp_dir = M.resolve_kotlin_lsp_dir(mason_package_dir, is_windows)
  end

  -- Fallback to environment variable if not found in Mason
  if not kotlin_lsp_dir then
    local env_dir = os.getenv("KOTLIN_LSP_DIR")
    if env_dir then
      kotlin_lsp_dir = M.resolve_kotlin_lsp_dir(env_dir, is_windows) or env_dir
    else
      vim.notify(
        "KOTLIN_LSP_DIR environment variable is not set and Kotlin LSP not found in Mason",
        vim.log.levels.ERROR
      )
      return
    end
  end

  -- Check that the lib directory exists
  local lib_dir = kotlin_lsp_dir .. (is_windows and "\\lib" or "/lib")
  if vim.fn.isdirectory(lib_dir) == 0 then
    vim.notify("The 'lib' directory does not exist at: " .. lib_dir, vim.log.levels.ERROR)
    return
  end

  -- Build command. Priority:
  --   1. `bin/intellij-server`           — v262.4739.0+ native launcher. Manages its
  --      own JBR; jre_path is ignored (the entry-point class lives in `modules/`,
  --      not on `lib/*`, so a manual `java -cp lib/* …` can't work).
  --   2. real `kotlin-lsp.sh` script     — old layout (pre-v262.4739.0). If the user
  --      set jre_path, parse JVM args out of the script and invoke java directly;
  --      otherwise just run the script.
  --   3. manual `java -cp lib/* …`       — KOTLIN_LSP_DIR installs with no launcher.
  local cmd = nil
  local cmd_env = nil

  local sep = is_windows and "\\" or "/"
  local intellij_server_name = is_windows and "intellij-server.exe" or "intellij-server"
  local intellij_server_path = kotlin_lsp_dir .. sep .. "bin" .. sep .. intellij_server_name
  local legacy_launcher_name = is_windows and "kotlin-lsp.cmd" or "kotlin-lsp.sh"
  local legacy_launcher_path = kotlin_lsp_dir .. sep .. legacy_launcher_name

  local has_intellij_server = vim.fn.executable(intellij_server_path) == 1
  local has_legacy_launcher = vim.fn.executable(legacy_launcher_path) == 1

  if has_intellij_server then
    if opts.jre_path then
      vim.notify(
        "kotlin.nvim: ignoring jre_path since bin/intellij-server (v262.4739.0+) manages its own JBR. "
          .. "Remove jre_path or downgrade kotlin-lsp if you need a custom JRE.",
        vim.log.levels.WARN
      )
    end
    cmd = { intellij_server_path, "--stdio", "--system-path=" .. workspace_dir }
  elseif has_legacy_launcher and opts.jre_path then
    -- Legacy layout, custom JRE: invoke java directly with JVM args parsed from the script.
    local java_bin = M.resolve_java_bin(opts.jre_path, is_windows)
    if not java_bin then
      return
    end
    local jvm_args = M.parse_launcher_jvm_args(legacy_launcher_path)

    cmd = { java_bin }
    vim.list_extend(cmd, jvm_args)
    vim.list_extend(cmd, {
      "-cp",
      lib_dir .. sep .. "*",
      "com.jetbrains.ls.kotlinLsp.KotlinLspServerKt",
      "--stdio",
      "--system-path=" .. workspace_dir,
    })
  elseif has_legacy_launcher then
    cmd = { legacy_launcher_path, "--stdio", "--system-path=" .. workspace_dir }
  else
    -- No launcher at all: manual java invocation. Only viable for legacy installs
    -- where com.jetbrains.ls.kotlinLsp.KotlinLspServerKt is on `lib/*`.
    local java_bin = M.resolve_java_bin(opts.jre_path, is_windows)
    if not java_bin then
      return
    end
    cmd = {
      java_bin,
      "-cp",
      lib_dir .. sep .. "*",
      "com.jetbrains.ls.kotlinLsp.KotlinLspServerKt",
      "--stdio",
      "--system-path=" .. workspace_dir,
    }
  end

  -- Pass additional JVM args via IJ_JAVA_OPTIONS environment variable
  if opts.jvm_args and type(opts.jvm_args) == "table" and #opts.jvm_args > 0 then
    cmd_env = { IJ_JAVA_OPTIONS = table.concat(opts.jvm_args, " ") }
  end

  require("kotlin.autocommands").setup()
  require("kotlin.autocommands").setup_inlay_hints(opts)
  require("kotlin.autocommands").setup_folding(opts)
  require("kotlin.diagnostics").setup()
  require("kotlin.package").setup()

  -- Priority-grouped so workspace markers win over per-module build files,
  -- keeping multi-module projects on a single root.
  local default_root_markers = {
    { "settings.gradle", "settings.gradle.kts", "mvnw", "mvnw.cmd", ".git" },
    { "build.gradle", "build.gradle.kts", "pom.xml" },
  }

  local root_markers = opts.root_markers or default_root_markers

  -- Build LSP settings with support for new features
  local settings = {
    uri_timeout_ms = 5000,
  }

  -- Add inlay hints configuration if specified
  -- These are flat boolean settings at the top level, matching VSCode extension format
  if opts.inlay_hints then
    settings["jetbrains.kotlin.hints.parameters"] = opts.inlay_hints.parameters ~= false
    settings["jetbrains.kotlin.hints.parameters.compiled"] = opts.inlay_hints.parameters_compiled ~= false
    settings["jetbrains.kotlin.hints.parameters.excluded"] = opts.inlay_hints.parameters_excluded == true
    settings["jetbrains.kotlin.hints.settings.types.property"] = opts.inlay_hints.types_property ~= false
    settings["jetbrains.kotlin.hints.settings.types.variable"] = opts.inlay_hints.types_variable ~= false
    settings["jetbrains.kotlin.hints.type.function.return"] = opts.inlay_hints.function_return ~= false
    settings["jetbrains.kotlin.hints.type.function.parameter"] = opts.inlay_hints.function_parameter ~= false
    settings["jetbrains.kotlin.hints.settings.lambda.return"] = opts.inlay_hints.lambda_return ~= false
    settings["jetbrains.kotlin.hints.lambda.receivers.parameters"] = opts.inlay_hints.lambda_receivers_parameters
      ~= false
    settings["jetbrains.kotlin.hints.settings.value.ranges"] = opts.inlay_hints.value_ranges ~= false
    settings["jetbrains.kotlin.hints.value.kotlin.time"] = opts.inlay_hints.kotlin_time ~= false
  end

  -- Build initialization options (sent during LSP initialization)
  local init_options = vim.empty_dict()

  -- JDK for symbol resolution goes in init_options, not settings (matching VSCode).
  -- v262.4739.0 renamed this from defaultJdk → defaultSdk; we send both for
  -- backwards compatibility with older builds.
  if opts.jdk_for_symbol_resolution then
    init_options.defaultSdk = opts.jdk_for_symbol_resolution
    init_options.defaultJdk = opts.jdk_for_symbol_resolution
  end

  -- buildTools: map of workspace folder URI → build importer ("gradle", "maven",
  -- "" for none, or omitted for any). Mirrors the VSCode `intellij.buildTool`
  -- setting (LSP-807). Keyed by the workspace root URI.
  if opts.build_tool ~= nil then
    local workspace_uri = vim.uri_from_fname(current_dir)
    init_options.buildTools = { [workspace_uri] = opts.build_tool }
  end

  vim.lsp.config.kotlin_lsp = {
    cmd = cmd,
    cmd_env = cmd_env,
    filetypes = { "kotlin" },
    root_markers = root_markers,
    settings = settings,
    init_options = init_options,
    capabilities = {
      textDocument = {
        inlayHint = {
          dynamicRegistration = true,
        },
        foldingRange = {
          dynamicRegistration = false,
          lineFoldingOnly = true,
        },
        callHierarchy = {
          dynamicRegistration = false,
        },
      },
    },
    -- Handle workspace/configuration requests from the server
    -- This is crucial for inlay hints - the server requests configuration dynamically
    handlers = {
      ["workspace/configuration"] = function(_, params, _)
        local result = {}
        for _, item in ipairs(params.items or {}) do
          local section = item.section

          if section == "jetbrains.kotlin" then
            -- Server requested the jetbrains.kotlin section
            -- Build a nested object from our flat settings
            local kotlin_config = { hints = {} }

            if opts.inlay_hints then
              kotlin_config.hints = {
                parameters = opts.inlay_hints.parameters ~= false,
                ["parameters.compiled"] = opts.inlay_hints.parameters_compiled ~= false,
                ["parameters.excluded"] = opts.inlay_hints.parameters_excluded == true,
                settings = {
                  types = {
                    property = opts.inlay_hints.types_property ~= false,
                    variable = opts.inlay_hints.types_variable ~= false,
                  },
                  lambda = {
                    ["return"] = opts.inlay_hints.lambda_return ~= false,
                  },
                  value = {
                    ranges = opts.inlay_hints.value_ranges ~= false,
                  },
                },
                type = {
                  ["function"] = {
                    ["return"] = opts.inlay_hints.function_return ~= false,
                    parameter = opts.inlay_hints.function_parameter ~= false,
                  },
                },
                lambda = {
                  receivers = {
                    parameters = opts.inlay_hints.lambda_receivers_parameters ~= false,
                  },
                },
                value = {
                  kotlin = {
                    time = opts.inlay_hints.kotlin_time ~= false,
                  },
                },
              }
            end

            table.insert(result, kotlin_config)
          elseif section and settings[section] ~= nil then
            -- Return the setting value for other requested sections
            table.insert(result, settings[section])
          else
            -- Return nil/null for unknown sections
            table.insert(result, vim.NIL)
          end
        end
        return result
      end,
      -- The completion apply command positions the caret via showDocument;
      -- place it in the current buffer instead of switching windows/scrolling.
      ["window/showDocument"] = function(_, params, ctx)
        return require("kotlin.completion").show_document(params, ctx)
      end,
    },
    -- Make command-driven completion behave like the VS Code client (client
    -- inserts nothing, server applies text/imports/caret). Completion is
    -- otherwise broken in Neovim. See lua/kotlin/completion.lua for the details.
    on_init = function(client)
      require("kotlin.completion").attach(client)
    end,
  }

  -- Enable only after the config above is assigned, otherwise a stray client
  -- starts from whatever else owns the kotlin_lsp name (e.g. nvim-lspconfig).
  vim.lsp.enable("kotlin_lsp")
end

M.settings = { uri_timeout_ms = 5000 }

-- Resolve the actual kotlin-lsp install root inside `base_dir`.
-- v262.4739.0+ Mason packages put everything under a versioned subdirectory
-- (e.g. base_dir/kotlin-server-262.4739.0/); older builds extracted directly
-- into base_dir. We pick whichever variant contains a `lib/` directory.
function M.resolve_kotlin_lsp_dir(base_dir, is_windows)
  local sep = is_windows and "\\" or "/"

  -- Direct layout (legacy): base_dir/lib/
  if vim.fn.isdirectory(base_dir .. sep .. "lib") == 1 then
    return base_dir
  end

  -- Versioned layout (v262.4739.0+): base_dir/kotlin-server-*/lib/
  local matches = vim.fn.glob(base_dir .. sep .. "kotlin-server-*", false, true)
  for _, dir in ipairs(matches) do
    if vim.fn.isdirectory(dir .. sep .. "lib") == 1 then
      return dir
    end
  end

  return nil
end

-- Parse JVM arguments from the bundled launcher script.
-- Extracts --add-opens, --enable-native-access, -D, and -X flags.
function M.parse_launcher_jvm_args(launcher_path)
  local args = {}
  local content = vim.fn.readfile(launcher_path)

  for _, line in ipairs(content) do
    -- Strip trailing backslash (sh) or caret (cmd) continuation characters and whitespace
    local trimmed = line:gsub("[\\^]%s*$", ""):match("^%s*(.-)%s*$")

    if
      trimmed:match("^%-%-add%-opens%s")
      or trimmed:match("^%-%-enable%-native%-access")
      or trimmed:match("^%-D")
      or trimmed:match("^%-X")
    then
      -- Split on whitespace in case --add-opens and its value are on the same token
      for token in trimmed:gmatch("%S+") do
        table.insert(args, token)
      end
    end
  end

  return args
end

-- Resolve a java binary for the fallback path (when no launcher script is available).
-- Priority: 1. User-specified jre_path, 2. JAVA_HOME, 3. System java
function M.resolve_java_bin(jre_path, is_windows)
  local java_bin = "java"
  local java_executable = is_windows and "java.exe" or "java"

  if jre_path then
    java_bin = jre_path .. "/bin/" .. java_executable
    if vim.fn.executable(java_bin) ~= 1 then
      vim.notify("Java executable not found at: " .. java_bin, vim.log.levels.ERROR)
      return nil
    end
  elseif vim.env.JAVA_HOME then
    java_bin = vim.env.JAVA_HOME .. "/bin/" .. java_executable
    if vim.fn.executable(java_bin) ~= 1 then
      vim.notify("Java executable not found at: " .. java_bin, vim.log.levels.ERROR)
      return nil
    end
  else
    if vim.fn.executable("java") ~= 1 then
      vim.notify(
        "No Java runtime found. Please install Java or configure jre_path in your setup.",
        vim.log.levels.ERROR
      )
      return nil
    end
  end

  -- Verify JRE version
  local jre = require("kotlin.jre")
  if not jre.is_supported_version(java_bin) then
    vim.notify(
      string.format(
        "Java version %d or higher is required to run Kotlin LSP.\n"
          .. "Please set jre_path in your config to point to a JRE installation with version %d or higher.",
        jre.minimum_supported_jre_version,
        jre.minimum_supported_jre_version
      ),
      vim.log.levels.ERROR
    )
    return nil
  end

  return java_bin
end

return M
