local M = {}

local orig_diagnostic_set = nil

M.hints_enabled = true -- Toggle for HINT severity

local stored_diagnostics = {}
local storage_initialized = false

local function setup_efficient_storage()
  if storage_initialized then
    return
  end

  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function(args)
      local bufnr = args.buf
      local ok, filetype = pcall(vim.api.nvim_buf_get_option, bufnr, "filetype")
      if ok and filetype == "kotlin" then
        if not stored_diagnostics[bufnr] then
          stored_diagnostics[bufnr] = {}
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function(args)
      local bufnr = args.buf
      if stored_diagnostics[bufnr] then
        stored_diagnostics[bufnr] = nil
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      stored_diagnostics = {}
    end,
  })

  storage_initialized = true
end

local function filter_diagnostics(diagnostics)
  if not diagnostics then
    return diagnostics
  end

  return vim.tbl_filter(function(diagnostic)
    if not M.hints_enabled and diagnostic.severity == vim.diagnostic.severity.HINT then
      return false -- Remove this diagnostic
    end
    return true
  end, diagnostics)
end

local function refresh_diagnostics()
  if not orig_diagnostic_set then
    return
  end

  for bufnr, ns_diagnostics in pairs(stored_diagnostics) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local ok, filetype = pcall(vim.api.nvim_buf_get_option, bufnr, "filetype")
      if ok and filetype == "kotlin" then
        for ns, _ in pairs(vim.diagnostic.get_namespaces()) do
          vim.diagnostic.reset(ns, bufnr)
        end

        for ns_id, diagnostics in pairs(ns_diagnostics) do
          if diagnostics and #diagnostics > 0 then
            orig_diagnostic_set(ns_id, bufnr, filter_diagnostics(diagnostics), {})
          end
        end
      end
    end
  end
end

function M.toggle_hints()
  M.hints_enabled = not M.hints_enabled

  local status = M.hints_enabled and "enabled" or "disabled"

  local message = string.format("Kotlin HINT diagnostics %s", status)
  vim.notify(message, vim.log.levels.INFO, {
    title = "Kotlin Diagnostics",
    timeout = 2000,
  })

  refresh_diagnostics()

  return M.hints_enabled
end

function M.setup()
  if orig_diagnostic_set then
    return
  end

  orig_diagnostic_set = vim.diagnostic.set

  setup_efficient_storage()

  vim.diagnostic.set = function(namespace, bufnr, diagnostics, opts)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      local ok, filetype = pcall(vim.api.nvim_buf_get_option, bufnr, "filetype")
      if ok and filetype == "kotlin" and diagnostics and #diagnostics > 0 then
        if not stored_diagnostics[bufnr] then
          stored_diagnostics[bufnr] = {}
        end

        stored_diagnostics[bufnr][namespace] = vim.deepcopy(diagnostics)
      end
    end

    if orig_diagnostic_set then
      orig_diagnostic_set(namespace, bufnr, filter_diagnostics(diagnostics), opts or {})
    end
  end

  vim.api.nvim_create_user_command("KotlinHintsToggle", function()
    M.toggle_hints()
  end, {
    desc = "Toggle visibility of HINT severity diagnostics",
  })
end

return M
