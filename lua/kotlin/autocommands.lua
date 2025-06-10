local api = vim.api
local decompiler = require("kotlin.decompiler")

local M = {}

-- Register autocommands for the supported protocols
function M.setup()
  -- Create an autogroup for our commands
  local augroup = api.nvim_create_augroup("KotlinDecompile", { clear = true })

  -- Add autocommands for jar and jrt protocols
  for _, protocol in ipairs(decompiler.supported_protocols) do
    api.nvim_create_autocmd("BufReadCmd", {
      pattern = protocol .. "://*",
      group = augroup,
      callback = function()
        decompiler.open_classfile(vim.fn.expand("<amatch>"))
      end,
      desc = "Decompile " .. protocol .. " files via Kotlin LS",
    })
  end
end

return M
