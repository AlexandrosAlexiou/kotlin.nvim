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

-- Register commands
function M.setup()
  vim.api.nvim_create_user_command("KotlinExportWorkspaceToJson", function()
    M.export_workspace_to_json()
  end, {
    desc = "Export workspace structure to workspace.json",
  })
end

return M
