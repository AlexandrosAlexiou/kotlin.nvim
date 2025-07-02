---@mod Kotlin LSP extensions for Neovim and kotlin-ls by JetBrains

local api = vim.api
local lsp = require("kotlin.lsp")
local kotlin = require("kotlin")

local M = {}

M.supported_protocols = { "jar", "jrt" }

--- Open special URIs like `jar://` or `jrt://` and decompile content
--- Uses the Kotlin language server to decompile and show the contents
---
---@param fname string
function M.open_classfile(fname)
  local uri = fname
  -- Make sure the URI is properly formatted
  if not (vim.startswith(uri, "jar://") or vim.startswith(uri, "jrt://")) then
    uri = vim.uri_from_fname(fname)
    if not vim.startswith(uri, "file://") then
      return
    end
  end

  local clients = lsp.get_clients({ name = "kotlin_ls" })
  local client = clients[1]

  assert(client, "Must have a `kotlin-ls` client to load class file or jdt uri")

  local buf = api.nvim_get_current_buf()
  vim.bo[buf].modifiable = true
  vim.bo[buf].swapfile = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "java"

  local content
  local function handler(err, result)
    assert(not err, vim.inspect(err))
    content = result

    -- Extract code from the result object
    local code = result.code

    -- Process the code
    local normalized = string.gsub(code, "\r\n", "\n")
    local source_lines = vim.split(normalized, "\n", { plain = true })

    -- Update the buffer with the decompiled code
    api.nvim_buf_set_lines(buf, 0, -1, false, source_lines)

    -- Set the filetype based on the language field
    if result.language then
      vim.bo[buf].filetype = result.language:lower()
    end

    -- Make the buffer read-only
    vim.bo[buf].modifiable = false
  end

  local command = {
    command = "decompile",
    arguments = { uri },
  }

  lsp.execute_command(command, handler)
  -- Need to block. Otherwise logic could run that sets the cursor to a position
  -- that's still missing.
  vim.wait(kotlin.settings.jdt_uri_timeout_ms, function()
    return content ~= nil
  end)
end

return M
