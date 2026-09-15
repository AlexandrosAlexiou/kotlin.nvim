---@mod kotlin.intellij Handlers for kotlin-lsp's `intellij/*` protocol extensions
---
--- kotlin-lsp v263.4702.0+ only uses these when the client declares
--- `intellijExtensions = true` in its initialization options. They carry the
--- parts of IntelliJ's ModCommand-based intentions/quick fixes that plain LSP
--- cannot express (a "choose one" menu, copying to the clipboard, starting a
--- rename) plus build-import progress. Without the flag the server silently
--- withholds every intention that needs one of them.

local M = {}

local BUILD_LOG_NAME = "kotlin-lsp://build-log"

local build_log_bufnr = nil

-- Blocked-folder reports already shown to the user, keyed by uri .. reason, so
-- the server's repeated `intellij/workspaceImportStatus` pushes don't spam.
local reported_blocks = {}

--- Scratch buffer that collects build-tool import output (`intellij/importLog`).
---@return integer bufnr
function M.build_log_bufnr()
  if build_log_bufnr and vim.api.nvim_buf_is_valid(build_log_bufnr) then
    return build_log_bufnr
  end
  build_log_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(build_log_bufnr, BUILD_LOG_NAME)
  vim.bo[build_log_bufnr].buftype = "nofile"
  vim.bo[build_log_bufnr].bufhidden = "hide"
  vim.bo[build_log_bufnr].swapfile = false
  vim.bo[build_log_bufnr].filetype = "log"
  return build_log_bufnr
end

--- Append lines to the build log, scrolling any window showing it.
---@param text string
function M.append_build_log(text)
  local bufnr = M.build_log_bufnr()
  local lines = vim.split(text or "", "\n", { plain = true, trimempty = true })
  if #lines == 0 then
    return
  end
  local count = vim.api.nvim_buf_line_count(bufnr)
  local empty = count == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
  vim.api.nvim_buf_set_lines(bufnr, empty and 0 or count, -1, false, lines)
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(bufnr), 0 })
  end
end

--- Open the build log in a split (bottom), reusing an existing window.
function M.open_build_log()
  local bufnr = M.build_log_bufnr()
  local wins = vim.fn.win_findbuf(bufnr)
  if #wins > 0 then
    vim.api.nvim_set_current_win(wins[1])
  else
    vim.cmd("botright 15split")
    vim.api.nvim_win_set_buf(0, bufnr)
  end
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(bufnr), 0 })
end

-- `intellij/chooseAction`: a ModCommand offers several actions; show them and
-- run the pick through `chooseModCommandAction`. The chosen action may itself
-- yield another menu, which arrives as a follow-up notification.
local function choose_action(params, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client or type(params) ~= "table" or type(params.entries) ~= "table" then
    return
  end
  vim.schedule(function()
    vim.ui.select(params.entries, {
      prompt = params.title or "Choose action",
      format_item = function(entry)
        return entry.name
      end,
    }, function(choice)
      if not choice then
        return
      end
      client:exec_cmd({
        title = choice.name,
        command = "chooseModCommandAction",
        arguments = { params.sessionId, choice.index },
      }, {}, function(err)
        if err then
          vim.notify("kotlin.nvim: action failed: " .. vim.inspect(err), vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

-- `intellij/copyToClipboard`: ModCopyToClipboard.
local function copy_to_clipboard(params)
  if type(params) ~= "table" or type(params.content) ~= "string" then
    return
  end
  vim.schedule(function()
    vim.fn.setreg("+", params.content)
    vim.fn.setreg('"', params.content)
    vim.notify("kotlin.nvim: copied to clipboard", vim.log.levels.INFO)
  end)
end

-- `intellij/runEditorCommand`: the server asks the editor to drive its own UI
-- after an edit (e.g. "Introduce variable" finishing with an inline rename).
-- The server emits VS Code command ids; these are their Neovim equivalents.
local function trigger_completion()
  if vim.fn.mode() ~= "i" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("a", true, false, true), "n", false)
  end
  vim.schedule(function()
    if vim.lsp.completion and vim.lsp.completion.get then
      vim.lsp.completion.get()
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n", false)
    end
  end)
end

local EDITOR_COMMANDS = {
  ["editor.action.rename"] = function()
    vim.lsp.buf.rename()
  end,
  ["editor.action.triggerSuggest"] = trigger_completion,
  ["editor.action.triggerParameterHints"] = function()
    vim.lsp.buf.signature_help()
  end,
}

local unsupported_reported = {}

local function run_editor_command(params)
  if type(params) ~= "table" or type(params.command) ~= "string" then
    return
  end
  local fn = EDITOR_COMMANDS[params.command]
  if not fn then
    if not unsupported_reported[params.command] then
      unsupported_reported[params.command] = true
      vim.notify(
        ("kotlin.nvim: the server asked for editor command %q, which has no Neovim equivalent yet"):format(
          params.command
        ),
        vim.log.levels.WARN
      )
    end
    return
  end
  -- The notification follows the workspace/applyEdit it belongs to; run after
  -- that edit has landed in the buffer.
  vim.schedule(function()
    local ok, err = pcall(fn, params.arguments or {})
    if not ok then
      vim.notify(("kotlin.nvim: editor command %s failed: %s"):format(params.command, tostring(err)), vim.log.levels.ERROR)
    end
  end)
end

-- Tool named by the last `started` event; `succeeded` events omit it.
local current_import_tool = nil

-- `intellij/importLog`: build-tool import output. `started`/`failed`/`succeeded`
-- mark the phases; everything else is a log line.
local function import_log(params)
  if type(params) ~= "table" then
    return
  end
  vim.schedule(function()
    if params.started and params.tool then
      current_import_tool = params.tool
    end
    local tool = params.tool or current_import_tool or "Build"
    if params.started then
      M.append_build_log(("== %s import started =="):format(tool))
      vim.notify(("kotlin.nvim: %s import started (:KotlinBuildLog for output)"):format(tool), vim.log.levels.INFO)
      return
    end
    if params.message and params.message ~= "" then
      M.append_build_log(params.message)
    end
    if params.failed then
      vim.notify(("kotlin.nvim: %s import failed. See :KotlinBuildLog"):format(tool), vim.log.levels.ERROR)
    elseif params.succeeded then
      vim.notify(("kotlin.nvim: %s import finished"):format(tool), vim.log.levels.INFO)
    end
  end)
end

local BLOCK_MESSAGES = {
  ambiguousBuildSystem = function(folder)
    return ("project import blocked for %s: several build systems found (%s). Set build_tool = \"...\" and run :KotlinReloadWorkspace"):format(
      folder.folderUri,
      table.concat(folder.candidates or {}, ", ")
    )
  end,
  noBuildSystemFound = function(folder)
    return ("project import skipped for %s: no supported build system found"):format(folder.folderUri)
  end,
}

-- `intellij/workspaceImportStatus`: folders whose import cannot start.
local function workspace_import_status(params)
  if type(params) ~= "table" or type(params.blockedFolders) ~= "table" then
    return
  end
  for _, folder in ipairs(params.blockedFolders) do
    local key = tostring(folder.folderUri) .. "|" .. tostring(folder.reason)
    if not reported_blocks[key] then
      reported_blocks[key] = true
      local build = BLOCK_MESSAGES[folder.reason]
      local msg = build and build(folder)
        or ("project import blocked for %s: %s"):format(folder.folderUri, tostring(folder.reason))
      local level = folder.reason == "ambiguousBuildSystem" and vim.log.levels.WARN or vim.log.levels.INFO
      vim.schedule(function()
        vim.notify("kotlin.nvim: " .. msg, level)
      end)
    end
  end
end

--- Forget which blocked folders were already reported (after a reload, so a
--- persisting block is shown again).
function M.reset_reported()
  reported_blocks = {}
end

--- Handlers to merge into the client's `handlers` table.
---@return table<string, function>
function M.handlers()
  local function notification(fn)
    return function(_, params, ctx)
      fn(params, ctx)
    end
  end
  return {
    ["intellij/chooseAction"] = notification(choose_action),
    ["intellij/copyToClipboard"] = notification(copy_to_clipboard),
    ["intellij/runEditorCommand"] = notification(run_editor_command),
    ["intellij/importLog"] = notification(import_log),
    ["intellij/workspaceImportStatus"] = notification(workspace_import_status),
  }
end

return M
