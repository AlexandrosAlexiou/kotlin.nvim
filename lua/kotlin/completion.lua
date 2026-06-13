---@mod kotlin.completion Workaround for kotlin-lsp's command-driven completion
---
--- JetBrains' kotlin-lsp does not put the inserted text in its completion items.
--- Each item comes back with an *empty* `textEdit` (newText = "", zero-width
--- range) plus a `command` (`jetbrains.kotlin.completion.apply`). The real text,
--- imports and caret are applied server-side: when the client runs that command
--- the server replies with `workspace/applyEdit` (text + imports) and
--- `window/showDocument` (caret). VS Code's language client inserts nothing on
--- accept and just runs the command, so it gets the full behaviour for free.
---
--- Neovim frontends (builtin completion, nvim-cmp, blink.cmp) instead fall back
--- to inserting the item's own text (the `label`, since `newText` is empty) and
--- *then* run the command, so the server's edit lands on top of the
--- already-inserted text and the caret ends up mid-identifier (`Ap|p`).
---
--- This module makes Neovim behave like VS Code: we keep the apply command and
--- turn the client's own insertion into a **no-op** (a text edit that replaces
--- the typed prefix with itself). The buffer is therefore unchanged when the
--- command runs, so the server's `applyEdit` — which is a diff against the
--- document it has synced — lands correctly and brings imports + parentheses
--- with it, and `window/showDocument` places the caret. Nothing is lost.
---
--- Requires the frontend to execute the item's `command` (builtin, nvim-cmp and
--- blink.cmp all do) and the server-driven `window/showDocument` to be honoured
--- (handled in lua/kotlin.lua). The proper fix is upstream returning a real
--- `textEdit` (kotlin-lsp already does this for the "JetBrains Air" client);
--- see docs/jetbrains-issue.md.

local M = {}

local APPLY_COMMAND = "jetbrains.kotlin.completion.apply"
local DATA_KEY = "KotlinCompletionItemKey"

-- No-op edits for the most recent completion list, keyed by the server's
-- completion id. `completionItem/resolve` re-sends the empty server edit, so we
-- restore the no-op from here to keep insertion deferred to the command.
local noop_edits = {}

-- True for items that defer their insertion to the kotlin-lsp apply command.
local function is_command_driven(item)
  return type(item) == "table"
    and type(item.command) == "table"
    and item.command.command == APPLY_COMMAND
end

local function item_id(item)
  return item.data and item.data[DATA_KEY]
end

-- Build a no-op text edit over the identifier prefix ending at the completion
-- position: it replaces the typed prefix with itself, so the client inserts
-- nothing and the buffer still matches the document the server will edit.
-- Note: offsets are measured in bytes, which match LSP character offsets for
-- ASCII identifiers (the common case for Kotlin symbols).
local function noop_prefix_edit(params)
  local pos = params.position
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  local line = vim.api.nvim_buf_get_lines(bufnr, pos.line, pos.line + 1, false)[1] or ""

  local start = pos.character
  while start > 0 and line:sub(start, start):match("[%w_$]") do
    start = start - 1
  end

  return {
    range = {
      start = { line = pos.line, character = start },
      ["end"] = { line = pos.line, character = pos.character },
    },
    newText = line:sub(start + 1, pos.character),
  }
end

-- Turn each command-driven item's own insertion into a no-op, keeping the apply
-- command so the server performs the real insertion (like the VS Code client).
local function patch_completion(result, params)
  local items = result.items or result
  if type(items) ~= "table" then
    return
  end

  local edit
  noop_edits = {}
  for _, item in ipairs(items) do
    if is_command_driven(item) then
      edit = edit or noop_prefix_edit(params)
      item.textEdit = { range = edit.range, newText = edit.newText }
      item.insertTextFormat = 1 -- PlainText: no snippet expansion of the no-op
      local id = item_id(item)
      if id ~= nil then
        noop_edits[id] = item.textEdit
      end
    end
  end
end

-- `completionItem/resolve` re-sends the empty server edit; restore our no-op so
-- the client still inserts nothing and defers to the command. Documentation and
-- other resolved fields are left untouched.
local function patch_resolve(result)
  if not is_command_driven(result) then
    return
  end
  local id = item_id(result)
  local edit = id ~= nil and noop_edits[id] or nil
  if edit then
    result.textEdit = { range = edit.range, newText = edit.newText }
    result.insertTextFormat = 1
  end
end

--- Wrap a client's `request` so completion and resolve responses are normalized
--- before any frontend (builtin completion, nvim-cmp, blink.cmp) sees them.
--- Frontends issue these requests with an inline callback, bypassing the
--- configured `handlers` table, so the client method is the only universal hook.
--- Idempotent.
---@param client vim.lsp.Client
function M.attach(client)
  if client._kotlin_completion_wrapped then
    return
  end
  client._kotlin_completion_wrapped = true

  local orig_request = client.request
  client.request = function(self, method, params, handler, bufnr)
    if handler and (method == "textDocument/completion" or method == "completionItem/resolve") then
      local inner = handler
      handler = function(err, result, ctx, config)
        if not err and result then
          if method == "textDocument/completion" then
            patch_completion(result, params)
          else
            patch_resolve(result)
          end
        end
        return inner(err, result, ctx, config)
      end
    end
    return orig_request(self, method, params, handler, bufnr)
  end
end

--- Handler for the server-initiated `window/showDocument` request. The apply
--- command uses it to place the caret after inserting; handle that in the
--- current buffer directly (the default handler may switch windows/scroll), and
--- delegate anything else to the default handler.
---@param result lsp.ShowDocumentParams
function M.show_document(result, ctx)
  local ok_uri, bufnr = pcall(vim.uri_to_bufnr, result.uri)
  if
    ok_uri
    and not result.external
    and result.selection
    and bufnr == vim.api.nvim_get_current_buf()
  then
    local s = result.selection.start
    pcall(vim.api.nvim_win_set_cursor, 0, { s.line + 1, s.character })
    return { success = true }
  end
  return vim.lsp.handlers["window/showDocument"](nil, result, ctx)
end

return M
