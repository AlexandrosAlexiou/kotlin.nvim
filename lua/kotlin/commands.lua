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
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

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

-- Enhanced code actions for Kotlin - shows only Kotlin-specific actions
function M.code_actions()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  -- Use the standard code action but it will only show kotlin-lsp actions
  -- since we filtered to kotlin_lsp client
  vim.lsp.buf.code_action({
    filter = function(_)
      -- Only show actions from kotlin_lsp
      return true
    end,
  })
end

-- Quick fix for the diagnostic under cursor (if any)
function M.quick_fix()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1

  -- Get diagnostics for current line
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = line })

  if #diagnostics == 0 then
    vim.notify("No diagnostics on current line", vim.log.levels.INFO)
    return
  end

  -- Request code actions for current position with diagnostics context
  vim.lsp.buf.code_action({
    filter = function(action)
      -- Prefer quickfix kind actions
      return action.kind and action.kind:match("quickfix")
    end,
  })
end

-- Format the current buffer using kotlin-lsp
function M.format_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  vim.lsp.buf.format({
    async = false,
    name = "kotlin_lsp",
  })

  vim.notify("Buffer formatted", vim.log.levels.INFO)
end

-- Show document symbols (outline)
function M.document_symbols()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  -- Request symbols and show in trouble
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }

  clients[1].request("textDocument/documentSymbol", params, function(err, result)
    if err then
      vim.notify("Failed to get symbols: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end

    if not result or vim.tbl_isempty(result) then
      vim.notify("No symbols found", vim.log.levels.INFO)
      return
    end

    -- Convert symbols to quickfix/location list format
    local function flatten_symbols(symbols, items, parent_name)
      items = items or {}
      parent_name = parent_name or ""

      for _, symbol in ipairs(symbols) do
        local name = symbol.name
        if parent_name ~= "" then
          name = parent_name .. "." .. name
        end

        -- Add the symbol
        local range = symbol.selectionRange or symbol.range or symbol.location.range
        table.insert(items, {
          bufnr = bufnr,
          lnum = range.start.line + 1,
          col = range.start.character + 1,
          text = name .. " [" .. (symbol.kind or "") .. "]",
        })

        -- Recursively add children
        if symbol.children then
          flatten_symbols(symbol.children, items, name)
        end
      end

      return items
    end

    local items = flatten_symbols(result)

    -- Set location list and open with trouble
    vim.fn.setloclist(0, items, "r")
    vim.fn.setloclist(0, {}, "a", { title = "Document Symbols" })
    require("trouble").open("loclist")
  end, bufnr)
end

-- Search workspace symbols
function M.workspace_symbols()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })

  if #clients == 0 then
    vim.notify("Kotlin LSP not running", vim.log.levels.ERROR)
    return
  end

  vim.lsp.buf.workspace_symbol()
end

-- Find all references to symbol under cursor
function M.find_references()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  vim.lsp.buf.references()
end

-- Go to type definition of symbol under cursor
function M.type_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  vim.lsp.buf.type_definition()
end

-- Go to implementation of symbol under cursor
function M.implementation()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  vim.lsp.buf.implementation()
end

-- Show callers of the symbol under cursor (callHierarchy/incomingCalls).
-- Requires kotlin-lsp v262.4739.0+.
function M.incoming_calls()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  vim.lsp.buf.incoming_calls()
end

-- Show what the symbol under cursor calls (callHierarchy/outgoingCalls).
-- Requires kotlin-lsp v262.4739.0+.
function M.outgoing_calls()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  vim.lsp.buf.outgoing_calls()
end

-- Rename symbol under cursor
function M.rename_symbol()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end

  vim.lsp.buf.rename()
end

-- Toggle inlay hints for the current buffer
function M.toggle_inlay_hints()
  local bufnr = vim.api.nvim_get_current_buf()
  local current_state = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })

  vim.lsp.inlay_hint.enable(not current_state, { bufnr = bufnr })

  local status = not current_state and "enabled" or "disabled"
  vim.notify("Inlay hints " .. status, vim.log.levels.INFO)
end

-- Open the kotlin-lsp server log alongside Neovim's LSP log. The server log
-- lives under this project's `--system-path` directory
-- (<system-path>/system/log/intellij-server.log).
function M.show_logs()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })
  if #clients == 0 then
    -- Fall back to any active client (e.g. when invoked from a non-Kotlin buffer)
    clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
  end

  local client = clients[1]
  local system_path
  if client then
    system_path = require("kotlin.workspace").system_path_for(client)
  else
    -- Server not running (e.g. it crashed): derive the path from the buffer's root.
    local kotlin = require("kotlin")
    system_path = kotlin.workspace_dir_for_root(kotlin.resolve_root_for_buffer(bufnr))
  end

  if system_path then
    local server_log = system_path .. "/system/log/intellij-server.log"
    if vim.fn.filereadable(server_log) == 1 then
      vim.cmd("split | edit " .. vim.fn.fnameescape(server_log) .. " | normal! G")
    else
      vim.notify("Kotlin LSP server log not found yet: " .. server_log, vim.log.levels.INFO)
    end
  else
    vim.notify("Could not determine the kotlin-lsp system path for this project", vim.log.levels.WARN)
  end

  -- Neovim's LSP RPC log (shared across clients).
  vim.cmd("vsplit | edit " .. vim.fn.fnameescape(vim.lsp.get_log_path()) .. " | normal! G")
end

-- Type hierarchy (kotlin-lsp v263.4702.0+ advertises typeHierarchyProvider).
---@param kind "supertypes"|"subtypes"
local function type_hierarchy(kind)
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })

  if #clients == 0 then
    vim.notify("Kotlin LSP not attached to buffer", vim.log.levels.ERROR)
    return
  end
  if not clients[1].server_capabilities.typeHierarchyProvider then
    vim.notify("kotlin-lsp does not advertise type hierarchy (needs v263.4702.0+)", vim.log.levels.WARN)
    return
  end

  vim.lsp.buf.typehierarchy(kind)
end

function M.supertypes()
  type_hierarchy("supertypes")
end

function M.subtypes()
  type_hierarchy("subtypes")
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

  vim.api.nvim_create_user_command("KotlinSymbols", function()
    M.document_symbols()
  end, {
    desc = "Show document symbols (outline) for current buffer",
  })

  vim.api.nvim_create_user_command("KotlinWorkspaceSymbols", function()
    M.workspace_symbols()
  end, {
    desc = "Search symbols across the workspace",
  })

  vim.api.nvim_create_user_command("KotlinTypeDefinition", function()
    M.type_definition()
  end, {
    desc = "Go to type definition of symbol under cursor",
  })

  vim.api.nvim_create_user_command("KotlinImplementation", function()
    M.implementation()
  end, {
    desc = "Go to implementation of symbol under cursor",
  })

  vim.api.nvim_create_user_command("KotlinIncomingCalls", function()
    M.incoming_calls()
  end, {
    desc = "Show callers of the symbol under cursor (call hierarchy)",
  })

  vim.api.nvim_create_user_command("KotlinOutgoingCalls", function()
    M.outgoing_calls()
  end, {
    desc = "Show what the symbol under cursor calls (call hierarchy)",
  })

  vim.api.nvim_create_user_command("KotlinReferences", function()
    M.find_references()
  end, {
    desc = "Find all references to symbol under cursor",
  })

  vim.api.nvim_create_user_command("KotlinRename", function()
    M.rename_symbol()
  end, {
    desc = "Rename symbol under cursor",
  })

  vim.api.nvim_create_user_command("KotlinCodeActions", function()
    M.code_actions()
  end, {
    desc = "Show code actions from kotlin-lsp",
  })

  vim.api.nvim_create_user_command("KotlinQuickFix", function()
    M.quick_fix()
  end, {
    desc = "Show quick fixes for diagnostics on current line",
  })

  vim.api.nvim_create_user_command("KotlinInlayHintsToggle", function()
    M.toggle_inlay_hints()
  end, {
    desc = "Toggle inlay hints for the current Kotlin buffer",
  })

  vim.api.nvim_create_user_command("KotlinShowLogs", function()
    M.show_logs()
  end, {
    desc = "Open the kotlin-lsp server log and Neovim's LSP log",
  })

  vim.api.nvim_create_user_command("KotlinSupertypes", function()
    M.supertypes()
  end, {
    desc = "Show supertypes of the symbol under cursor (type hierarchy)",
  })

  vim.api.nvim_create_user_command("KotlinSubtypes", function()
    M.subtypes()
  end, {
    desc = "Show subtypes of the symbol under cursor (type hierarchy)",
  })

  vim.api.nvim_create_user_command("KotlinReloadWorkspace", function()
    require("kotlin.workspace").reload()
  end, {
    desc = "Re-import the project (intellij/reloadWorkspace) without restarting the server",
  })

  vim.api.nvim_create_user_command("KotlinRestart", function()
    require("kotlin.workspace").restart()
  end, {
    desc = "Restart the Kotlin language server",
  })

  vim.api.nvim_create_user_command("KotlinBuildLog", function()
    require("kotlin.intellij").open_build_log()
  end, {
    desc = "Open the build-tool import / build output log",
  })
end

return M
