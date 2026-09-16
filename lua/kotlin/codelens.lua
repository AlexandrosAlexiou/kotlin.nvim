---@mod kotlin.codelens Run/Debug code lenses above `main` functions
---
--- With `runMainCodeLens = true` in the initialization options kotlin-lsp
--- (v263.4702.0+) emits two `textDocument/codeLens` items above every `main`
--- function, both carrying the client-side command `intellij.jvm.runMain` with
--- `{ mainClass, uri, noDebug }`. Neovim renders them through
--- |vim.lsp.codelens| and this module routes the command to kotlin.dap.

local M = {}

M.RUN_MAIN_COMMAND = "intellij.jvm.runMain"

local WRAPPED = "_kotlin_codelens_wrapped"

-- Nerd Font stand-ins for the codicons the server puts in lens titles
-- ("$(play) Run", "$(debug) Debug"), which Neovim would render literally.
-- `code_lens.icons` replaces the table; `false` shows text only.
local DEFAULT_ICONS = {
  play = "\u{f04b}",
  debug = "\u{f188}",
}

local options = {}

local function icons()
  if options.icons == nil then
    return DEFAULT_ICONS
  end
  return options.icons
end

-- Replace VS Code codicon markup with the configured text, or drop it.
local function retitle(title)
  return (title:gsub("%$%(([%w_.-]+)%)%s*", function(icon)
    local set = icons()
    local replacement = set and set[icon]
    return replacement and (replacement .. " ") or ""
  end))
end

-- Column to draw the lens at: the indent of its line. The server anchors each
-- lens to the `main` identifier, and Neovim indents the virtual line to that
-- column, leaving the lens floating right of the code it sits above.
local function indent_col(bufnr, row)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  if not line then
    return nil
  end
  local indent = line:match("^[ \t]*") or ""
  local tabs = select(2, indent:gsub("\t", ""))
  local col = #indent - tabs + tabs * vim.bo[bufnr].tabstop
  return math.min(col, #line)
end

local function normalize(result, bufnr)
  for _, lens in ipairs(result or {}) do
    if lens.command and lens.command.title then
      lens.command.title = retitle(lens.command.title)
    end
    if options.align ~= false and bufnr and vim.api.nvim_buf_is_loaded(bufnr) and lens.range then
      local col = indent_col(bufnr, lens.range.start.line)
      if col then
        lens.range.start.character = col
      end
    end
  end
  return result
end

--- Rewrite this client's code lens responses (titles, placement). Neovim's
--- code lens provider passes its own handler to every request, so the client
--- method is the only hook. Idempotent.
---@param client vim.lsp.Client
function M.attach(client)
  if client[WRAPPED] then
    return
  end
  client[WRAPPED] = true
  local request = client.request
  ---@diagnostic disable-next-line: duplicate-set-field
  client.request = function(self, method, params, handler, bufnr)
    if handler and method == "textDocument/codeLens" then
      local inner = handler
      handler = function(err, result, ctx, config)
        return inner(err, normalize(result, ctx and ctx.bufnr or bufnr), ctx, config)
      end
    end
    return request(self, method, params, handler, bufnr)
  end
end

local function attach(bufnr)
  if vim.lsp.codelens.enable then
    -- Neovim 0.12+: auto-refreshing lenses.
    vim.lsp.codelens.enable(true, { bufnr = bufnr })
    return
  end
  -- Neovim 0.11: refresh on the usual triggers.
  local group = vim.api.nvim_create_augroup("KotlinCodeLens" .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "TextChanged" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      vim.lsp.codelens.refresh({ bufnr = bufnr })
    end,
  })
  vim.lsp.codelens.refresh({ bufnr = bufnr })
end

--- Register the `intellij.jvm.runMain` command and enable lenses on attach.
---@param opts table plugin options (`code_lens.enabled`, `code_lens.icons`, `code_lens.align`)
function M.setup(opts)
  opts = opts or {}
  options = opts.code_lens or {}
  if options.enabled == false then
    return
  end

  vim.lsp.commands[M.RUN_MAIN_COMMAND] = function(command)
    local args = command.arguments and command.arguments[1]
    if type(args) ~= "table" or not args.mainClass then
      vim.notify("kotlin.nvim: malformed run lens: " .. vim.inspect(command.arguments), vim.log.levels.ERROR)
      return
    end
    require("kotlin.dap").run_main(args)
  end

  local group = vim.api.nvim_create_augroup("KotlinCodeLens", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not (client and client.name == "kotlin_lsp") then
        return
      end
      if not client.server_capabilities.codeLensProvider then
        return
      end
      attach(args.buf)
    end,
    desc = "Enable kotlin-lsp run/debug code lenses",
  })
end

--- Run-lens arguments for every `main` in `bufnr`, fetched synchronously.
---@param bufnr integer
---@return { mainClass: string, uri?: string, noDebug?: boolean }[]
function M.main_targets(bufnr)
  local client = vim.lsp.get_clients({ name = "kotlin_lsp", bufnr = bufnr })[1]
  if not client then
    return {}
  end
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  local resp = client:request_sync("textDocument/codeLens", params, 5000, bufnr)
  local targets, seen = {}, {}
  for _, lens in ipairs(resp and resp.result or {}) do
    local cmd = lens.command
    if cmd and cmd.command == M.RUN_MAIN_COMMAND then
      local a = cmd.arguments and cmd.arguments[1]
      if type(a) == "table" and a.mainClass and not seen[a.mainClass] then
        seen[a.mainClass] = true
        table.insert(targets, { mainClass = a.mainClass, uri = a.uri or vim.uri_from_bufnr(bufnr) })
      end
    end
  end
  return targets
end

return M
