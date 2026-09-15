---@mod kotlin.decompiler Library and JDK sources as LSP-served buffers
---
--- Go-to-definition into a dependency or the JDK returns `jar:///...!/...` and
--- `jrt:///...!/...` locations. Neovim keeps such names verbatim and
--- |vim.uri_from_bufnr()| returns them unchanged, so a BufReadCmd on these
--- schemes fills the buffer through the server's `decompile` command (attached
--- sources when available, decompiled bytecode otherwise) and attaches the
--- kotlin_lsp client to it, like the VS Code client's document selector does.
--- Hover, navigation and semantic highlighting then work inside library code.

local api = vim.api

local M = {}

M.supported_protocols = { "jar", "jrt" }

--- Whether a buffer name / URI denotes a library source document.
---@param name string?
---@return boolean
function M.is_virtual(name)
  return type(name) == "string" and (vim.startswith(name, "jar:") or vim.startswith(name, "jrt:"))
end

--- Attach `client` to a library source buffer (idempotent).
---@param bufnr integer
---@param client vim.lsp.Client
function M.attach(bufnr, client)
  if not vim.lsp.buf_is_attached(bufnr, client.id) then
    pcall(vim.lsp.buf_attach_client, bufnr, client.id)
  end
end

--- Attach the client to every library source buffer already open (after a restart).
---@param client vim.lsp.Client
function M.attach_open_buffers(client)
  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(bufnr) and M.is_virtual(api.nvim_buf_get_name(bufnr)) then
      M.attach(bufnr, client)
    end
  end
end

--- BufReadCmd entry point for `jar://*` / `jrt://*` buffers.
---@param fname string buffer name (from <amatch>)
function M.open_classfile(fname)
  local bufnr = vim.fn.bufnr(fname)
  if bufnr == -1 then
    bufnr = api.nvim_get_current_buf()
  end
  local uri = api.nvim_buf_get_name(bufnr)
  local client = vim.lsp.get_clients({ name = "kotlin_lsp" })[1]

  local result, err
  if client then
    local timeout = require("kotlin").settings.uri_timeout_ms
    local resp = client:request_sync("workspace/executeCommand", { command = "decompile", arguments = { uri } }, timeout, 0)
    if not resp then
      err = "timed out after " .. timeout .. "ms"
    elseif resp.err then
      err = vim.inspect(resp.err)
    elseif type(resp.result) == "table" and type(resp.result.code) == "string" then
      result = resp.result
    else
      err = "empty response"
    end
  else
    err = "Kotlin LSP not running"
  end
  if not result then
    vim.notify("kotlin.nvim: failed to decompile " .. uri .. ": " .. err, vim.log.levels.WARN)
  end

  local code = result and result.code or ("// Failed to load source: " .. tostring(err))
  vim.bo[bufnr].modifiable = true
  api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split((code:gsub("\r\n", "\n")), "\n", { plain = true }))
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].readonly = true
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = true
  -- Not a file on disk: keeps Neovim's own LSP auto-start away (we attach
  -- below) and refuses :write.
  vim.bo[bufnr].buftype = "nowrite"

  local lang = result and type(result.language) == "string" and result.language:lower() or nil
  if not lang or lang == "" then
    lang = uri:match("%.kt$") and "kotlin" or "java"
  end
  vim.bo[bufnr].filetype = lang
  pcall(vim.treesitter.start, bufnr, lang)

  if client and result then
    M.attach(bufnr, client)
  end
end

return M
