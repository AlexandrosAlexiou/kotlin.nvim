local M = {}

-- Options passed to setup(), merged with any `.kotlin-lsp.lua` at LSP start.
local global_opts = {}

-- Root markers in effect (set in setup_kotlin_lsp), used by helpers that
-- need to resolve a project root outside of the LSP config callbacks.
local active_root_markers = nil

-- Exit code the launcher uses when the bundled build's licence has expired
-- (AppExitCodes.LICENSE_ERROR). kotlin-lsp builds carry a time-limited EAP
-- licence; VS Code reports this as "the bundled build has expired".
local EXPIRED_BUILD_EXIT_CODE = 7

function M.setup(opts)
  opts = opts or {}
  global_opts = opts

  -- Register user commands eagerly so :KotlinHealth (and friends) are available
  -- even when LSP startup fails. The LSP itself is wired lazily on FileType.
  require("kotlin.commands").setup()
  require("kotlin.dap").setup(opts)
  require("kotlin.file_templates").setup(opts)
  require("kotlin.codelens").setup(opts)
  require("kotlin.workspace").setup_auto_reload(opts)

  vim.api.nvim_create_user_command("KotlinCleanWorkspace", function()
    M.clean_workspace()
  end, { desc = "Delete the Kotlin LSP indexes for the current project and restart" })

  -- Create an autocommand group for kotlin-lsp
  local group = vim.api.nvim_create_augroup("kotlin_lsp", { clear = true })

  -- Set up the autocmd to configure Kotlin LSP when a Kotlin file is opened.
  -- Java buffers never start the server on their own (see setup_kotlin_lsp);
  -- they attach to a server a Kotlin file already started for the same root.
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

-- `--system-path` for a project root: `<base>/<name>-<hash>`, where the hash
-- disambiguates projects that share a directory name (the server keys its own
-- per-workspace state the same way).
---@param root string
---@return string
function M.workspace_dir_for_root(root)
  local is_windows = vim.fn.has("win32") == 1
  local project_name = vim.fn.fnamemodify(root, ":p:h:t")
  local hash = vim.fn.sha256(vim.fn.fnamemodify(root, ":p"))
  return M.get_workspace_base_dir() .. (is_windows and "\\" or "/") .. project_name .. "-" .. hash:sub(1, 8)
end

--- Delete the server state for the current project and restart. See
--- |kotlin.workspace.clean|.
function M.clean_workspace()
  require("kotlin.workspace").clean()
end

-- Search upward from `start_dir` for `filename`, returning its path or nil.
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

-- Whether Kotlin LSP should stay off for this buffer: either the buffer-local
-- flag is set, or a `.disable-kotlin-lsp` marker exists at or above the file.
local function is_kotlin_lsp_disabled(bufnr)
  if vim.b[bufnr].disable_kotlin_lsp then
    return true
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  local buf_dir = name ~= "" and vim.fn.fnamemodify(name, ":p:h") or vim.fn.getcwd()
  return find_file_upward(".disable-kotlin-lsp", buf_dir) ~= nil
end

-- Undo a prior `vim.lsp.enable("kotlin_lsp")` so Neovim's built-in auto-start
-- stops firing, and detach any client already running on this buffer. Needed
-- because enablement is global and sticky: once we've enabled the config for
-- one buffer, dropping a `.disable-kotlin-lsp` marker (or setting the buffer
-- flag) afterwards would otherwise be ignored until nvim restarts.
local function disable_kotlin_lsp(bufnr)
  vim.lsp.enable("kotlin_lsp", false)
  for _, client in ipairs(vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })) do
    vim.lsp.stop_client(client.id)
  end
end

-- Priority-grouped so workspace markers win over per-module build files,
-- keeping multi-module projects on a single root.
local default_root_markers = {
  { "settings.gradle", "settings.gradle.kts", "mvnw", "mvnw.cmd", ".git" },
  { "build.gradle", "build.gradle.kts", "pom.xml" },
}

-- Resolve the project root for `bufnr`, honoring the priority-grouped
-- `root_markers` (a list of marker groups, highest priority first) exactly like
-- Neovim's own `root_markers` resolution. Accepts a flat list too. Falls back
-- to the current working directory when no marker matches.
local function resolve_root(bufnr, root_markers, fallback)
  local groups = type(root_markers[1]) == "string" and { root_markers } or root_markers
  for _, group in ipairs(groups) do
    local root = vim.fs.root(bufnr, group)
    if root then
      return root
    end
  end
  return fallback
end

-- Is `path` inside directory `root`?
local function is_under(path, root)
  if not root or root == "" or path == "" then
    return false
  end
  path = vim.fs.normalize(path)
  root = vim.fs.normalize(root):gsub("/$", "")
  return path == root or vim.startswith(path, root .. "/")
end

--- The kotlin_lsp client already running for `root`, when `bufnr` (a file
--- buffer) lies inside that root. Java buffers only ever join such a client.
---@param root string
---@param bufnr integer
---@return vim.lsp.Client?
function M.running_client_for(root, bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" or not is_under(name, root) then
    return nil
  end
  for _, client in ipairs(vim.lsp.get_clients({ name = "kotlin_lsp" })) do
    if client.root_dir == root then
      return client
    end
  end
  return nil
end

--- Attach `client` to Java buffers already open under its root. Neovim only
--- attaches on FileType, which has long fired for buffers opened before the
--- server existed.
---@param client vim.lsp.Client
local function attach_open_java_buffers(client)
  local root = client.root_dir
  if not root then
    return
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(bufnr)
      and vim.bo[bufnr].buftype == ""
      and vim.bo[bufnr].filetype == "java"
      and not vim.lsp.buf_is_attached(bufnr, client.id)
      and is_under(vim.api.nvim_buf_get_name(bufnr), root)
      and not is_kotlin_lsp_disabled(bufnr)
    then
      vim.lsp.buf_attach_client(bufnr, client.id)
    end
  end
end

--- Project root for `bufnr` using the configured root markers.
---@param bufnr integer
---@return string
function M.resolve_root_for_buffer(bufnr)
  return resolve_root(bufnr, active_root_markers or global_opts.root_markers or default_root_markers, vim.fn.getcwd())
end

-- Map plugin options to kotlin-lsp inlay hint optionIds, keyed by their path
-- under the `jetbrains.kotlin.hints` section. The server flattens the
-- workspace/configuration response for `jetbrains.kotlin` into dot-paths and
-- string-matches them against IntelliJ's declarative inlay hint optionIds
-- (InlayInfoOption.kt), so these keys must spell the optionIds exactly.
-- Note: JetBrains' own VS Code package.json uses the bundle nameKeys
-- (`hints.settings.types.property`, ...) for four of these — those never
-- matched and must not be copied here.
local function inlay_hint_options(inlay)
  -- stylua: ignore start
  return {
    ["parameters"] = inlay.parameters ~= false,
    ["parameters.compiled"] = inlay.parameters_compiled ~= false,
    ["parameters.excluded"] = inlay.parameters_excluded == true,
    ["parameters.context"] = inlay.parameters_context == true,
    ["type.property"] = inlay.types_property ~= false,
    ["type.variable"] = inlay.types_variable ~= false,
    ["type.function.return"] = inlay.function_return ~= false,
    ["type.function.parameter"] = inlay.function_parameter ~= false,
    ["lambda.return"] = inlay.lambda_return ~= false,
    ["lambda.receivers.parameters"] = inlay.lambda_receivers_parameters ~= false,
    ["value.ranges"] = inlay.value_ranges ~= false,
    ["value.kotlin.time"] = inlay.kotlin_time ~= false,
    ["call.chains"] = inlay.call_chains == true,
  }
  -- stylua: ignore end
end

local DATA_SHARING_VALUES = { full = true, anonymous = true, none = true }
local REGION_VALUES =
  { africa = true, americas = true, apac = true, china = true, europe = true, middle_east = true, oceania = true }

-- Environment for the launcher process (merged with Neovim's environment).
local function launch_env(opts)
  local env = {}

  -- Pass additional JVM args via IJ_JAVA_OPTIONS environment variable
  if opts.jvm_args and type(opts.jvm_args) == "table" and #opts.jvm_args > 0 then
    local current = os.getenv("IJ_JAVA_OPTIONS")
    local extra = table.concat(opts.jvm_args, " ")
    env.IJ_JAVA_OPTIONS = current and current ~= "" and (current .. " " .. extra) or extra
  end

  -- Consent settings the VS Code extension asks for on first start. Unset means
  -- "none" / no region: the server shares nothing.
  if opts.data_sharing and opts.data_sharing ~= "none" then
    if DATA_SHARING_VALUES[opts.data_sharing] then
      env.INTELLIJ_DATA_SHARING = opts.data_sharing
    else
      vim.notify("kotlin.nvim: invalid data_sharing value " .. vim.inspect(opts.data_sharing), vim.log.levels.WARN)
    end
  end
  if opts.region then
    if REGION_VALUES[opts.region] then
      env.INTELLIJ_REGION = opts.region
    else
      vim.notify("kotlin.nvim: invalid region value " .. vim.inspect(opts.region), vim.log.levels.WARN)
    end
  end

  return env
end

-- Convert a `projects` entry (plugin spelling) to the server's ConfiguredProject.
-- `path` may be a URI, an absolute path or a path relative to `root`.
local function configured_project(entry, root)
  if type(entry) ~= "table" or type(entry.type) ~= "string" or type(entry.path) ~= "string" then
    vim.notify("kotlin.nvim: projects entries need `type` and `path`: " .. vim.inspect(entry), vim.log.levels.WARN)
    return nil
  end
  local path = entry.path
  if not path:match("^%a[%w+.-]*://") then
    if not vim.startswith(path, "/") and not path:match("^%a:[\\/]") then
      path = root .. "/" .. path
    end
    path = vim.uri_from_fname(vim.fn.fnamemodify(path, ":p"):gsub("[\\/]$", ""))
  end
  local project = { type = entry.type, path = path }
  project["java-home"] = entry.java_home or entry["java-home"]
  project["project-path"] = entry.project_path or entry["project-path"]
  project.env = entry.env
  project["system-properties"] = entry.system_properties or entry["system-properties"]
  return project
end

function M.setup_kotlin_lsp(opts)
  -- Honor the buffer flag / `.disable-kotlin-lsp` marker. This reactive check
  -- also stops a client already running on this buffer. The config's `root_dir`
  -- veto (below) is what authoritatively prevents *starts* regardless of which
  -- FileType autocmd fires first, but stopping here handles the case where the
  -- marker/flag is dropped while a client is live.
  if is_kotlin_lsp_disabled(0) then
    disable_kotlin_lsp(0)
    return
  end

  opts = opts or {}
  local is_windows = vim.fn.has("win32") == 1

  -- Get current buffer's directory as starting point for root detection
  local buf_dir = vim.fn.expand("%:p:h")
  if buf_dir == "" or buf_dir == "." then
    buf_dir = vim.fn.getcwd()
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

  -- Launch via bin/intellij-server, the native launcher shipped with
  -- kotlin-lsp v262.4739.0+. It manages its own bundled JBR, so there is no
  -- JRE or classpath to configure here.
  local sep = is_windows and "\\" or "/"
  local intellij_server_name = is_windows and "intellij-server.exe" or "intellij-server"
  local intellij_server_path = kotlin_lsp_dir .. sep .. "bin" .. sep .. intellij_server_name

  if vim.fn.executable(intellij_server_path) ~= 1 then
    vim.notify(
      "kotlin.nvim: bin/intellij-server not found at "
        .. intellij_server_path
        .. ". kotlin-lsp v262.4739.0+ is required — run :MasonInstall kotlin-lsp or update your install.",
      vim.log.levels.ERROR
    )
    return
  end

  require("kotlin.autocommands").setup()
  require("kotlin.autocommands").setup_inlay_hints(opts)
  require("kotlin.autocommands").setup_folding(opts)
  require("kotlin.diagnostics").setup()
  require("kotlin.package").setup()

  local root_markers = opts.root_markers or default_root_markers
  active_root_markers = root_markers

  -- Build LSP settings with support for new features
  ---@type table<string, integer|boolean>
  local settings = {
    uri_timeout_ms = 5000,
  }

  -- Add inlay hints configuration if specified
  -- These are flat boolean settings at the top level, one per optionId
  if opts.inlay_hints then
    for option, enabled in pairs(inlay_hint_options(opts.inlay_hints)) do
      settings["jetbrains.kotlin.hints." .. option] = enabled
    end
  end

  -- Build initialization options (sent during LSP initialization and again by
  -- :KotlinReloadWorkspace). The server decodes these as one object and drops
  -- everything if one field is ill-typed, so only well-formed values go in.
  local init_options = vim.empty_dict()

  -- Declares a JetBrains-aware client: unlocks the `intellij/*` notifications
  -- that ModCommand intentions need (see lua/kotlin/intellij.lua).
  init_options.intellijExtensions = true

  -- Run/Debug lenses above `main` functions (see lua/kotlin/codelens.lua).
  if not (opts.code_lens and opts.code_lens.enabled == false) then
    init_options.runMainCodeLens = true
  end

  -- JDK for symbol resolution goes in init_options, not settings (matching VSCode).
  if opts.jdk_for_symbol_resolution then
    init_options.defaultSdk = opts.jdk_for_symbol_resolution
  end

  if opts.disable_rocksdb_wal == true then
    init_options.disableRocksDBWriteAheadLog = true
  end

  local env = launch_env(opts)

  -- Also attach to Java buffers, like the VS Code client's document selector,
  -- so unsaved Java edits reach Kotlin analysis immediately (LSP-1053). The
  -- Kotlin server ships no Java language features of its own (those live in
  -- the "Java and Kotlin" server's java.lsp plugin), so a Java buffer only
  -- ever attaches to a server that a Kotlin file already started for the same
  -- root; it never starts one. java_files = false turns this off.
  local java_files = opts.java_files ~= false
  local filetypes = { "kotlin" }
  if java_files then
    table.insert(filetypes, "java")
  end

  local handlers = require("kotlin.intellij").handlers()

  -- Handle workspace/configuration requests from the server
  -- This is crucial for inlay hints - the server requests configuration dynamically
  handlers["workspace/configuration"] = function(_, params, _)
    local result = {}
    for _, item in ipairs(params.items or {}) do
      local section = item.section

      if section == "jetbrains.kotlin" then
        -- The server flattens this response into dot-paths and only
        -- renders hints whose optionId is present with value true, so
        -- the keys under `hints` must spell the optionIds exactly.
        local kotlin_config = vim.empty_dict()

        if opts.inlay_hints then
          kotlin_config = { hints = inlay_hint_options(opts.inlay_hints) }
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
  end

  -- The completion apply command positions the caret via showDocument;
  -- place it in the current buffer instead of switching windows/scrolling.
  handlers["window/showDocument"] = function(_, params, ctx)
    return require("kotlin.completion").show_document(params, ctx)
  end

  vim.lsp.config.kotlin_lsp = {
    -- The launcher command depends on the resolved root (per-project
    -- `--system-path`), which is only known once Neovim has picked the root.
    cmd = function(dispatchers, config)
      local root = config.root_dir or current_dir
      local workspace_dir = M.workspace_dir_for_root(root)
      vim.fn.mkdir(workspace_dir, "p")
      require("kotlin.workspace").set_system_path(root, workspace_dir)

      local cmd = { intellij_server_path, "--stdio", "--system-path=" .. workspace_dir }
      -- The launcher's debug log goes to stdout, which is the protocol channel
      -- in --stdio mode. Neovim cannot unset an inherited variable, so drop it
      -- through env(1) where available.
      if os.getenv("IJ_LAUNCHER_DEBUG") and not is_windows and vim.fn.executable("env") == 1 then
        cmd = vim.list_extend({ "env", "-u", "IJ_LAUNCHER_DEBUG" }, cmd)
      end
      return vim.lsp.rpc.start(cmd, dispatchers, {
        cwd = root,
        env = next(env) and env or nil,
      })
    end,
    filetypes = filetypes,
    root_markers = root_markers,
    -- Authoritative disable gate. Neovim consults this at start time, so a
    -- `.disable-kotlin-lsp` marker (or the buffer flag) is honored even when
    -- Neovim's built-in `nvim.lsp.enable` FileType autocmd fires before this
    -- plugin's. Not calling `on_dir` tells Neovim not to start a client.
    root_dir = function(bufnr, on_dir)
      if is_kotlin_lsp_disabled(bufnr) then
        return
      end
      local root = resolve_root(bufnr, root_markers, current_dir)
      if vim.bo[bufnr].filetype == "java" and not M.running_client_for(root, bufnr) then
        -- Only join a server already running for this root.
        return
      end
      on_dir(root)
    end,
    settings = settings,
    init_options = init_options,
    -- buildTools and projects must be keyed by / resolved against the actual
    -- workspace root, not getcwd(). Calculate them in before_init when the
    -- client's rootUri is known.
    before_init = function(params, config)
      local root = config.root_dir or current_dir
      if opts.build_tool ~= nil and params.rootUri then
        if not config.init_options.buildTools then
          config.init_options.buildTools = {}
        end
        config.init_options.buildTools[params.rootUri] = opts.build_tool
      end
      if type(opts.projects) == "table" and #opts.projects > 0 then
        local projects = {}
        for _, entry in ipairs(opts.projects) do
          local project = configured_project(entry, root)
          if project then
            table.insert(projects, project)
          end
        end
        config.init_options.projects = projects
      end
    end,
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
    handlers = handlers,
    -- Make command-driven completion behave like the VS Code client (client
    -- inserts nothing, server applies text/imports/caret). Completion is
    -- otherwise broken in Neovim. See lua/kotlin/completion.lua for the details.
    on_init = function(client)
      require("kotlin.completion").attach(client)
      require("kotlin.semantic_tokens").setup()
      require("kotlin.codelens").attach(client)
      -- Library/JDK source buffers opened before a restart are not in
      -- Neovim's own reattach set (they are not files).
      require("kotlin.decompiler").attach_open_buffers(client)
      if java_files then
        attach_open_java_buffers(client)
      end
    end,
    on_exit = function(code, signal)
      if code == EXPIRED_BUILD_EXIT_CODE then
        vim.schedule(function()
          vim.notify(
            "kotlin.nvim: this kotlin-lsp build has expired (its embedded licence ran out) and refuses to start. "
              .. "Update kotlin-lsp (:MasonInstall kotlin-lsp or a newer release) and restart Neovim.",
            vim.log.levels.ERROR
          )
        end)
      elseif code ~= 0 and signal == 0 then
        vim.schedule(function()
          vim.notify(
            ("kotlin.nvim: kotlin-lsp exited with code %d. See :KotlinShowLogs"):format(code),
            vim.log.levels.WARN
          )
        end)
      end
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

return M
