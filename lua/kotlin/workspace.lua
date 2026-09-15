---@mod kotlin.workspace Workspace lifecycle: reload, restart, cache cleaning
---
--- Mirrors the VS Code extension's "Reimport Project", "Restart Language
--- Server" and "Clear Caches and Restart" commands, and its auto-reload on
--- build-file save.

local M = {}

-- Build descriptors whose save triggers a workspace reload.
local BUILD_FILE_NAMES = {
  ["pom.xml"] = true,
  ["build.gradle"] = true,
  ["build.gradle.kts"] = true,
  ["settings.gradle"] = true,
  ["settings.gradle.kts"] = true,
}

-- `--system-path` used for each client root, recorded when the launcher is
-- started so :KotlinShowLogs / :KotlinCleanWorkspace find the right directory.
local system_paths = {}

---@param root string
---@param path string
function M.set_system_path(root, path)
  system_paths[root] = path
end

---@param client vim.lsp.Client
---@return string?
function M.system_path_for(client)
  return client and client.root_dir and system_paths[client.root_dir] or nil
end

---@param bufnr? integer
---@return vim.lsp.Client?
local function pick_client(bufnr)
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })
  if #clients == 0 then
    clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
  end
  return clients[1]
end

--- Ask the server to re-import the workspace, resending the initialization
--- options (v263.4702.0+, `intellij/reloadWorkspace`). Unlike a restart this
--- keeps the process and its indexes.
---@param opts? { silent?: boolean, client?: vim.lsp.Client }
function M.reload(opts)
  opts = opts or {}
  local client = opts.client or pick_client(vim.api.nvim_get_current_buf())
  if not client then
    vim.notify("kotlin.nvim: Kotlin LSP not running", vim.log.levels.ERROR)
    return
  end
  require("kotlin.intellij").reset_reported()
  local init_options = client.config.init_options
  if init_options == nil or (type(init_options) == "table" and next(init_options) == nil) then
    init_options = vim.empty_dict()
  end
  client:request("intellij/reloadWorkspace", { initializationOptions = init_options }, function(err)
    if err then
      -- MethodNotFound: server predates v263.4702.0
      local msg = err.code == -32601 and "kotlin-lsp too old for intellij/reloadWorkspace (needs v263.4702.0+)"
        or ("failed to reload workspace: " .. vim.inspect(err))
      vim.notify("kotlin.nvim: " .. msg, vim.log.levels.ERROR)
      return
    end
    if not opts.silent then
      vim.notify("kotlin.nvim: workspace reloaded", vim.log.levels.INFO)
    end
  end)
end

-- Stop every kotlin_lsp client and call `on_stopped` once they have exited.
local function stop_all(on_stopped)
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
  for _, client in ipairs(clients) do
    client:stop()
  end
  local deadline = vim.uv.now() + 8000
  local timer = vim.uv.new_timer()
  timer:start(100, 100, function()
    local pending = false
    for _, client in ipairs(clients) do
      if not client:is_stopped() then
        pending = true
      end
    end
    if pending and vim.uv.now() < deadline then
      return
    end
    timer:stop()
    timer:close()
    vim.schedule(function()
      if pending then
        for _, client in ipairs(clients) do
          client:stop(true)
        end
      end
      on_stopped()
    end)
  end)
end

-- Re-enable the config so Neovim starts a fresh client for already-open buffers.
local function start_again()
  vim.lsp.enable("kotlin_lsp", false)
  vim.lsp.enable("kotlin_lsp")
end

--- Stop and start the language server for all Kotlin buffers.
function M.restart()
  vim.notify("kotlin.nvim: restarting Kotlin LSP...", vim.log.levels.INFO)
  stop_all(function()
    start_again()
    vim.notify("kotlin.nvim: Kotlin LSP restarted", vim.log.levels.INFO)
  end)
end

local function remove_dir(dir)
  if vim.fn.isdirectory(dir) ~= 1 then
    return false
  end
  if vim.fn.has("win32") == 1 then
    vim.fn.system('rmdir /s /q "' .. dir .. '"')
  else
    vim.fn.system("rm -rf " .. vim.fn.shellescape(dir))
  end
  return true
end

--- Delete the server's on-disk state for the project of the current buffer
--- (or the running client's root) and restart: the plugin-managed
--- `--system-path` directory and the index directory the server reported in
--- `capabilities.experimental.indexDir`, nothing else.
---@param opts? { restart?: boolean }
function M.clean(opts)
  opts = opts or {}
  local kotlin = require("kotlin")
  local client = pick_client(vim.api.nvim_get_current_buf())
  local root = client and client.root_dir or kotlin.resolve_root_for_buffer(0)
  if not root then
    vim.notify("kotlin.nvim: could not determine the project root", vim.log.levels.ERROR)
    return
  end

  local system_path = system_paths[root] or kotlin.workspace_dir_for_root(root)
  -- v263.4702.0+ keeps the index inside the system path; older builds report a
  -- directory under the JetBrains analyzer cache, known only while running.
  local experimental = client and client.server_capabilities.experimental
  local index_dir = type(experimental) == "table" and experimental.indexDir or nil

  local function do_clean()
    local removed = {}
    if remove_dir(system_path) then
      table.insert(removed, system_path)
    end
    if index_dir and not vim.startswith(index_dir, system_path) and remove_dir(index_dir) then
      table.insert(removed, index_dir)
    end
    if #removed == 0 then
      vim.notify("kotlin.nvim: nothing to clean for " .. root, vim.log.levels.INFO)
    else
      vim.notify("kotlin.nvim: removed\n  " .. table.concat(removed, "\n  "), vim.log.levels.INFO)
    end
    if opts.restart ~= false then
      start_again()
    end
  end

  local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
  if #clients > 0 then
    vim.notify("kotlin.nvim: stopping Kotlin LSP to release the index...", vim.log.levels.INFO)
    stop_all(do_clean)
  else
    do_clean()
  end
end

--- Whether `path` is a build descriptor whose change warrants a re-import.
---@param path string
---@return boolean
function M.is_build_file(path)
  return BUILD_FILE_NAMES[vim.fn.fnamemodify(path, ":t")] == true
end

--- Reload the workspace when a build file is saved, honoring
--- `reload_workspace.on_build_file_save` = "always" | "ask" | "never".
---@param opts table plugin options
function M.setup_auto_reload(opts)
  local mode = (opts.reload_workspace or {}).on_build_file_save or "ask"
  if mode == "never" then
    return
  end
  local group = vim.api.nvim_create_augroup("KotlinAutoReloadWorkspace", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      local path = vim.api.nvim_buf_get_name(args.buf)
      if path == "" or not M.is_build_file(path) then
        return
      end
      local dir = vim.fn.fnamemodify(path, ":p:h")
      local client
      for _, c in ipairs(vim.lsp.get_clients({ name = "kotlin_lsp" })) do
        if c.root_dir and vim.startswith(dir, c.root_dir) then
          client = c
          break
        end
      end
      if not client then
        return
      end
      if mode == "always" then
        M.reload({ client = client, silent = true })
        return
      end
      vim.ui.select({ "Reload workspace", "Not now" }, {
        prompt = vim.fn.fnamemodify(path, ":t") .. " changed. Re-import the project?",
      }, function(choice)
        if choice == "Reload workspace" then
          M.reload({ client = client })
        end
      end)
    end,
    desc = "Reload the kotlin-lsp workspace when a build file is saved",
  })
end

return M
