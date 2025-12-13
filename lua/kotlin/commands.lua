local lsp = require("kotlin.lsp")

local M = {}

-- Export workspace structure to JSON file in current working directory
function M.export_workspace_to_json()
  local cwd = vim.fn.getcwd()

  if cwd == "" then
    vim.notify("No workspace opened", vim.log.levels.ERROR)
    return
  end

  lsp.execute_command({
    command = "exportWorkspace",
    arguments = { cwd },
  }, function(err, _)
    if err then
      vim.notify("Failed to export workspace: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end

    vim.notify("Exported workspace.json to " .. cwd, vim.log.levels.INFO)
  end)
end

-- Organize imports in the current buffer
function M.organize_imports()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_ls", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  -- Get the file URI for the current buffer
  local uri = vim.uri_from_bufnr(bufnr)

  lsp.execute_command({
    command = "kotlin.organize.imports",
    arguments = { uri },
  }, function(err, _)
    if err then
      vim.notify("Failed to organize imports: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end
  end)
end

-- Apply a mod command (used internally by kotlin-lsp for inspections/intentions)
-- This is the new mechanism for applying quick fixes
function M.apply_mod_command(command_data)
  if not command_data then
    vim.notify("No command data provided", vim.log.levels.ERROR)
    return
  end

  lsp.execute_command({
    command = "applyModCommand",
    arguments = { command_data },
  }, function(err, _)
    if err then
      vim.notify("Failed to apply mod command: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end

    vim.notify("Command applied", vim.log.levels.INFO)
  end)
end

-- Format the current buffer using kotlin-lsp
function M.format_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_ls", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  vim.lsp.buf.format({
    async = false,
    name = "kotlin_ls",
  })

  vim.notify("Buffer formatted", vim.log.levels.INFO)
end

-- Toggle inlay hints for the current buffer
function M.toggle_inlay_hints()
  local bufnr = vim.api.nvim_get_current_buf()
  local current_state = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })

  vim.lsp.inlay_hint.enable(not current_state, { bufnr = bufnr })

  local status = not current_state and "enabled" or "disabled"
  vim.notify("Inlay hints " .. status, vim.log.levels.INFO)
end

-- Register commands
function M.setup()
  vim.api.nvim_create_user_command("KotlinExportWorkspaceToJson", function()
    M.export_workspace_to_json()
  end, {
    desc = "Export workspace structure to workspace.json",
  })

  vim.api.nvim_create_user_command("KotlinOrganizeImports", function()
    M.organize_imports()
  end, {
    desc = "Organize imports in the current Kotlin file",
  })

  vim.api.nvim_create_user_command("KotlinFormat", function()
    M.format_buffer()
  end, {
    desc = "Format the current Kotlin buffer",
  })

  vim.api.nvim_create_user_command("KotlinInlayHintsToggle", function()
    M.toggle_inlay_hints()
  end, {
    desc = "Toggle inlay hints for the current Kotlin buffer",
  })
end

return M
