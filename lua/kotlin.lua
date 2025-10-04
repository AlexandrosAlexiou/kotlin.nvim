local M = {}

function M.setup(opts)
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

  vim.api.nvim_create_user_command("KotlinCleanWorkspace", function()
    M.clean_workspace()
  end, { desc = "Clean Kotlin LSP workspace for current project" })
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
  for _, client in ipairs(vim.lsp.get_clients({ name = "kotlin_ls" })) do
    vim.notify("Stopping Kotlin LSP...", vim.log.levels.INFO)
    vim.lsp.stop_client(client.id)
    vim.cmd("sleep 500m")
  end

  -- Remove workspace directory if it exists
  if vim.fn.isdirectory(workspace_dir) == 1 then
    if is_windows then
      vim.fn.system('rmdir /s /q "' .. workspace_dir .. '"')
    else
      vim.fn.system("rm -rf " .. workspace_dir)
    end
  end

  vim.notify("Workspace cleaned. Ready to restart Kotlin LSP.", vim.log.levels.INFO)
end

function M.setup_kotlin_lsp(opts)
  if vim.g.disable_lsp then
    return
  end

  opts = opts or {}
  local is_windows = vim.fn.has("win32") == 1

  -- Get current project info
  local current_dir = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(current_dir, ":p:h:t")
  local home = os.getenv("HOME")
  local workspace_dir = home .. "/.cache/kotlin-lsp-workspaces/" .. project_name

  -- Create workspace directory
  vim.fn.mkdir(workspace_dir, "p")

  local jre_path = opts.jre_path
  local java_bin = "java"

  if jre_path then
    local java_executable = is_windows and "java.exe" or "java"
    java_bin = jre_path .. "/bin/" .. java_executable

    if vim.fn.executable(java_bin) ~= 1 then
      vim.notify("Java executable not found at: " .. java_bin, vim.log.levels.ERROR)
      return
    end
  elseif vim.env.JAVA_HOME then
    local java_executable = is_windows and "java.exe" or "java"
    java_bin = vim.env.JAVA_HOME .. "/bin/" .. java_executable

    if vim.fn.executable(java_bin) ~= 1 then
      vim.notify("Java executable not found at: " .. java_bin, vim.log.levels.ERROR)
      return
    end
  end

  local jre = require("kotlin.jre")
  if not jre.is_supported_version(java_bin) then
    vim.notify(
      string.format(
        "Java version %d or higher is required to run Kotlin LSP.\n"
          .. "Please set jre_path in your config to point to a JRE installation with version %d or higher.",
        jre.minimum_supported_java_version,
        jre.minimum_supported_java_version
      ),
      vim.log.levels.ERROR
    )
    return
  end

  -- Find Kotlin LSP lib directory
  local kotlin_lsp_dir = nil
  local lib_dir = nil

  local mason_package_dir = vim.fn.expand("$MASON/packages/kotlin-lsp")

  if vim.fn.isdirectory(mason_package_dir) == 1 then
    if vim.fn.isdirectory(mason_package_dir .. "/lib") == 1 then
      lib_dir = mason_package_dir .. "/lib"
    end
  end

  -- Fallback to environment variable if not found in Mason
  if not lib_dir then
    kotlin_lsp_dir = os.getenv("KOTLIN_LSP_DIR")
    if not kotlin_lsp_dir then
      vim.notify(
        "KOTLIN_LSP_DIR environment variable is not set and Kotlin LSP not found in Mason",
        vim.log.levels.ERROR
      )
      return
    end

    lib_dir = kotlin_lsp_dir .. "/lib"
    if vim.fn.isdirectory(lib_dir) == 0 then
      vim.notify("The 'lib' directory does not exist at: " .. lib_dir, vim.log.levels.ERROR)
      return
    end
  end

  local default_jvm_args = {
    "--add-opens",
    "java.base/java.io=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.lang=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.lang.ref=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.lang.reflect=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.net=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.nio=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.nio.charset=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.text=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.time=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.util=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.util.concurrent=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.util.concurrent.atomic=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.util.concurrent.locks=ALL-UNNAMED",
    "--add-opens",
    "java.base/jdk.internal.vm=ALL-UNNAMED",
    "--add-opens",
    "java.base/sun.net.dns=ALL-UNNAMED",
    "--add-opens",
    "java.base/sun.nio.ch=ALL-UNNAMED",
    "--add-opens",
    "java.base/sun.nio.fs=ALL-UNNAMED",
    "--add-opens",
    "java.base/sun.security.ssl=ALL-UNNAMED",
    "--add-opens",
    "java.base/sun.security.util=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/com.apple.eawt=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/com.apple.eawt.event=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/com.apple.laf=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/com.sun.java.swing=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/com.sun.java.swing.plaf.gtk=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/java.awt=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/java.awt.dnd.peer=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/java.awt.event=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/java.awt.font=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/java.awt.image=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/java.awt.peer=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/javax.swing=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/javax.swing.plaf.basic=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/javax.swing.text=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/javax.swing.text.html=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/sun.awt=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/sun.awt.X11=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/sun.awt.datatransfer=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/sun.awt.image=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/sun.awt.windows=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/sun.font=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/sun.java2d=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/sun.lwawt=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/sun.lwawt.macosx=ALL-UNNAMED",
    "--add-opens",
    "java.desktop/sun.swing=ALL-UNNAMED",
    "--add-opens",
    "java.management/sun.management=ALL-UNNAMED",
    "--add-opens",
    "jdk.attach/sun.tools.attach=ALL-UNNAMED",
    "--add-opens",
    "jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED",
    "--add-opens",
    "jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED",
    "--add-opens",
    "jdk.jdi/com.sun.tools.jdi=ALL-UNNAMED",
    "--enable-native-access=ALL-UNNAMED",
  }

  local jvm_args = default_jvm_args
  if opts.jvm_args and type(opts.jvm_args) == "table" then
    for _, arg in ipairs(opts.jvm_args) do
      table.insert(jvm_args, arg)
    end
  end

  local cmd = { java_bin }

  for _, arg in ipairs(jvm_args) do
    table.insert(cmd, arg)
  end

  if is_windows then
    table.insert(cmd, "-cp")
    table.insert(cmd, lib_dir .. "\\*")
  else
    table.insert(cmd, "-cp")
    table.insert(cmd, lib_dir .. "/*")
  end

  table.insert(cmd, "com.jetbrains.ls.kotlinLsp.KotlinLspServerKt")
  table.insert(cmd, "--stdio")

  -- Use project-specific workspace directory for indexes
  table.insert(cmd, "--system-path=" .. workspace_dir)

  require("kotlin.autocommands").setup()
  require("kotlin.commands").setup()
  require("kotlin.diagnostics").setup()
  require("kotlin.package").setup()

  local default_root_markers = {
    "build.gradle",
    "build.gradle.kts",
    "pom.xml",
  }

  local root_markers = opts.root_markers or default_root_markers

  vim.lsp.config.kotlin_ls = {
    cmd = cmd,
    filetypes = { "kotlin" },
    root_markers = root_markers,
  }

  vim.lsp.enable("kotlin_ls")
end

M.settings = { uri_timeout_ms = 5000 }

return M
