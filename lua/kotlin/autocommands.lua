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

-- Setup inlay hints for Kotlin files
function M.setup_inlay_hints(opts)
  opts = opts or {}
  
  if not opts.inlay_hints then
    return
  end
  
  -- Create autogroup for inlay hints
  local augroup = api.nvim_create_augroup("KotlinInlayHints", { clear = true })
  
  -- Enable inlay hints by default when a Kotlin LSP attaches
  api.nvim_create_autocmd("LspAttach", {
    group = augroup,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == "kotlin_ls" then
        local bufnr = args.buf
        
        -- Check if the client supports inlay hints
        if client.server_capabilities.inlayHintProvider then
          -- Enable inlay hints by default unless explicitly disabled
          local should_enable = opts.inlay_hints.enabled ~= false
          
          if should_enable then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
          end
        end
      end
    end,
    desc = "Enable Kotlin inlay hints on LSP attach",
  })
end

return M
