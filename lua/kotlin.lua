local function setup(opts)
  opts = opts or {}

  local jre_path = opts.jre_path

  local java_bin = "java"
  if jre_path then
    local java_executable = vim.fn.has("win32") == 1 and "java.exe" or "java"
    java_bin = jre_path .. "/bin/" .. java_executable

    if vim.fn.executable(java_bin) ~= 1 then
      vim.notify("Java executable not found at: " .. java_bin, vim.log.levels.ERROR)
      return
    end
  elseif vim.env.JAVA_HOME then
    local java_executable = vim.fn.has("win32") == 1 and "java.exe" or "java"
    java_bin = vim.env.JAVA_HOME .. "/bin/" .. java_executable

    if vim.fn.executable(java_bin) ~= 1 then
      vim.notify("Java executable not found at: " .. java_bin, vim.log.levels.ERROR)
      return
    end
  end

  local kotlin_lsp_dir = os.getenv("KOTLIN_LSP_DIR")
  if not kotlin_lsp_dir then
    vim.notify("KOTLIN_LSP_DIR environment variable is not set", vim.log.levels.ERROR)
    return
  end

  local lib_dir = kotlin_lsp_dir .. "/lib"
  if vim.fn.isdirectory(lib_dir) == 0 then
    vim.notify("The 'lib' directory does not exist at: " .. lib_dir, vim.log.levels.ERROR)
    return
  end

  local cmd = {
    java_bin,
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
  }

  local is_windows = vim.fn.has("win32") == 1
  if is_windows then
    table.insert(cmd, "-cp")
    table.insert(cmd, lib_dir .. "\\*")
  else
    table.insert(cmd, "-cp")
    table.insert(cmd, lib_dir .. "/*")
  end

  table.insert(cmd, "com.jetbrains.ls.kotlinLsp.KotlinLspServerKt")
  table.insert(cmd, "--stdio")

  require("kotlin.autocommands").setup()
  require("kotlin.commands").setup()

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

local M = {
  setup = setup,
  settings = {
    jdt_uri_timeout_ms = 5000,
  },
}

return M
