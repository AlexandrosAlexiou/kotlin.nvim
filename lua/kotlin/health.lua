-- Health check module for kotlin.nvim. Run with:
--     :checkhealth kotlin
-- Reports launcher resolution, optional dependencies, and (when an LSP client
-- is attached) the negotiated server capabilities.

local M = {}

local h = vim.health or require("health")
local start = h.start or h.report_start
local ok = h.ok or h.report_ok
local warn = h.warn or h.report_warn
local err = h.error or h.report_error
local info = h.info or h.report_info

local function is_windows()
  return vim.fn.has("win32") == 1
end

local function check_neovim()
  start("Neovim")
  if vim.fn.has("nvim-0.11") == 1 then
    ok(("Neovim %s"):format(tostring(vim.version())))
  else
    err("Neovim 0.11+ is required (vim.lsp.foldexpr, vim.lsp.config, …)")
  end
end

local function check_dependencies()
  start("Dependencies")
  local checks = {
    { mod = "mason", name = "mason.nvim", required = true },
    { mod = "oil", name = "oil.nvim", required = false, note = "package navigation via 'go to definition'" },
    { mod = "trouble", name = "trouble.nvim", required = false, note = ":KotlinSymbols / :KotlinWorkspaceSymbols" },
    { mod = "dap", name = "nvim-dap", required = false, note = ":KotlinDebug" },
  }
  for _, c in ipairs(checks) do
    if pcall(require, c.mod) then
      ok(c.name .. " installed")
    else
      if c.required then
        err(c.name .. " is required but not installed")
      else
        warn(("%s not installed (optional — needed for %s)"):format(c.name, c.note))
      end
    end
  end
end

local function check_install()
  start("kotlin-lsp installation")
  local kotlin = require("kotlin")
  local sep = is_windows() and "\\" or "/"

  local mason_root = vim.fn.expand("$MASON/packages/kotlin-lsp")
  local mason_exists = vim.fn.isdirectory(mason_root) == 1
  if mason_exists then
    info("Mason package: " .. mason_root)
  else
    info("Mason package: not present (Mason root not detected)")
  end

  local env_dir = os.getenv("KOTLIN_LSP_DIR")
  if env_dir then
    info("$KOTLIN_LSP_DIR: " .. env_dir)
  end

  local resolved
  if mason_exists then
    resolved = kotlin.resolve_kotlin_lsp_dir(mason_root, is_windows())
  end
  if not resolved and env_dir then
    resolved = kotlin.resolve_kotlin_lsp_dir(env_dir, is_windows()) or env_dir
  end

  if not resolved then
    err("Could not locate a kotlin-lsp install. Run :MasonInstall kotlin-lsp or set $KOTLIN_LSP_DIR.")
    return
  end

  ok("Resolved kotlin_lsp_dir: " .. resolved)

  local lib = resolved .. sep .. "lib"
  if vim.fn.isdirectory(lib) == 1 then
    ok("lib/ directory present")
  else
    err("lib/ directory not found at " .. lib)
  end

  local intellij_server = resolved
    .. sep
    .. "bin"
    .. sep
    .. (is_windows() and "intellij-server.exe" or "intellij-server")

  if vim.fn.executable(intellij_server) == 1 then
    ok("Launcher: bin/intellij-server (v262.4739.0+) — " .. intellij_server)
    info("Uses its own bundled JBR — no separate JDK required to run the server.")
  else
    err(
      "bin/intellij-server not found under "
        .. resolved
        .. ". kotlin-lsp v262.4739.0+ is required — run :MasonInstall kotlin-lsp or update your install."
    )
  end
end

local function check_clients()
  start("Active LSP clients")
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })

  if #clients == 0 then
    info("No kotlin_lsp client attached. Open a .kt file in a Kotlin project to start the server.")
    return
  end

  for _, c in ipairs(clients) do
    ok(("kotlin_lsp (id=%d) attached to %d buffer(s)"):format(c.id, vim.tbl_count(c.attached_buffers or {})))
    info("  cmd: " .. vim.inspect(c.config.cmd))

    local caps = c.server_capabilities or {}
    local function cap(name, key)
      if caps[key] then
        ok("  " .. name)
      else
        warn("  " .. name .. " not advertised")
      end
    end
    cap("foldingRangeProvider", "foldingRangeProvider")
    cap("callHierarchyProvider", "callHierarchyProvider")
    cap("inlayHintProvider", "inlayHintProvider")
    cap("typeDefinitionProvider", "typeDefinitionProvider")
    cap("implementationProvider", "implementationProvider")
    cap("renameProvider", "renameProvider")
    cap("documentFormattingProvider", "documentFormattingProvider")

    local provider = caps.executeCommandProvider
    if type(provider) == "table" and provider.commands then
      info("  executeCommands: " .. table.concat(provider.commands, ", "))
      local needed = { "exportWorkspace", "kotlin.organize.imports", "interpolateFileTemplate", "start_debug_server" }
      for _, name in ipairs(needed) do
        if vim.tbl_contains(provider.commands, name) then
          ok("  command available: " .. name)
        else
          warn("  command missing: " .. name)
        end
      end
    end
  end
end

function M.check()
  check_neovim()
  check_dependencies()
  check_install()
  check_clients()
end

return M
