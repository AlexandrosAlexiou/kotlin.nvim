local M = {}

-- Helper functions
function M.get_clients(...)
  ---@diagnostic disable-next-line: deprecated
  local clients = (vim.lsp.get_clients or vim.lsp.get_active_clients)(...)
  return vim.tbl_map(M.add_client_methods, clients)
end

function M.add_client_methods(client)
  -- Placeholder for any client methods you want to add
  return client
end

function M.execute_command(command, callback, bufnr)
  local clients = {}
  local candidates = M.get_clients({ name = "kotlin_ls" })

  for _, c in pairs(candidates) do
    local command_provider = c.server_capabilities.executeCommandProvider
    local commands = type(command_provider) == "table" and command_provider.commands or {}
    if vim.tbl_contains(commands, command.command) then
      table.insert(clients, c)
    end
  end
  local num_clients = vim.tbl_count(clients)
  if num_clients == 0 then
    vim.notify("No LSP client found that supports " .. command.command, vim.log.levels.ERROR)
    return
  end

  if num_clients > 1 then
    vim.notify(
      "Multiple LSP clients found that support "
        .. command.command
        .. " you should have at most one kotlin-ls server running",
      vim.log.levels.WARN
    )
  end

  local co
  if not callback then
    co = coroutine.running()
    if co then
      callback = function(err, resp)
        coroutine.resume(co, err, resp)
      end
    end
  end
  clients[1]:request("workspace/executeCommand", command, callback, bufnr)
  if co then
    return coroutine.yield()
  end
end

return M
