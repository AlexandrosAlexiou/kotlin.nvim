local M = {}

--- Run a workspace/executeCommand on the kotlin_lsp client that advertises it.
---@param command lsp.Command
---@param callback? fun(err: lsp.ResponseError?, result: any)
---@param bufnr? integer
function M.execute_command(command, callback, bufnr)
  local client
  for _, c in ipairs(vim.lsp.get_clients({ name = "kotlin_lsp" })) do
    local provider = c.server_capabilities.executeCommandProvider
    if type(provider) == "table" and vim.tbl_contains(provider.commands or {}, command.command) then
      client = c
      break
    end
  end
  if not client then
    vim.notify("No LSP client found that supports " .. command.command, vim.log.levels.ERROR)
    return
  end
  client:request("workspace/executeCommand", command, callback, bufnr)
end

return M
