local lsp = require("kotlin.lsp")

local M = {}

-- VSCode extension's default Kotlin file templates.
-- Each template uses Apache Velocity syntax; the server interpolates ${PACKAGE_NAME},
-- ${NAME}, ${USER}, ${DATE}, etc. The literal `|` marks the desired caret position.
M.default_templates = {
  Class = '#if (${PACKAGE_NAME} && ${PACKAGE_NAME} != "")package ${PACKAGE_NAME}\n\n#end\nclass ${NAME} {\n\t|\n}',
  File = '#if (${PACKAGE_NAME} && ${PACKAGE_NAME} != "")package ${PACKAGE_NAME}\n\n#end\n|',
  Interface = '#if (${PACKAGE_NAME} && ${PACKAGE_NAME} != "")package ${PACKAGE_NAME}\n\n#end\ninterface ${NAME} {\n\t|\n}',
  ["Data Class"] = '#if (${PACKAGE_NAME} && ${PACKAGE_NAME} != "")package ${PACKAGE_NAME}\n\n#end\ndata class ${NAME}(|)\n',
  Enum = '#if (${PACKAGE_NAME} && ${PACKAGE_NAME} != "")package ${PACKAGE_NAME}\n\n#end\nenum class ${NAME} {\n\t|\n}',
  Annotation = '#if (${PACKAGE_NAME} && ${PACKAGE_NAME} != "")package ${PACKAGE_NAME}\n\n#end\nannotation class ${NAME}(|)',
  Object = '#if (${PACKAGE_NAME} && ${PACKAGE_NAME} != "")package ${PACKAGE_NAME}\n\n#end\nobject ${NAME} {\n\t|\n}',
}

-- Order in which templates are presented in the picker (matches VSCode UX).
M.default_template_order = { "Class", "File", "Interface", "Data Class", "Enum", "Annotation", "Object" }

local function buffer_is_empty(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 then
    return true
  end
  return #lines == 1 and lines[1] == ""
end

local function get_templates(opts)
  if opts and opts.file_templates and not vim.tbl_isempty(opts.file_templates) then
    return opts.file_templates
  end
  return M.default_templates
end

local function get_template_order(templates)
  local order = {}
  -- Preserve VSCode's order for defaults; for user overrides, sort alphabetically.
  for _, name in ipairs(M.default_template_order) do
    if templates[name] then
      table.insert(order, name)
    end
  end
  for name, _ in pairs(templates) do
    if not vim.tbl_contains(order, name) then
      table.insert(order, name)
    end
  end
  return order
end

-- Insert `content` into bufnr starting at line 0, then move the cursor to the
-- position of the literal `|` marker (and remove the marker). Falls back to
-- end-of-buffer if no marker is present.
local function apply_content(bufnr, content)
  local caret_line, caret_col = nil, nil
  local lines = vim.split(content, "\n", { plain = true })

  for i, line in ipairs(lines) do
    local idx = line:find("|", 1, true)
    if idx then
      caret_line = i - 1
      caret_col = idx - 1
      lines[i] = line:sub(1, idx - 1) .. line:sub(idx + 1)
      break
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  if caret_line and vim.api.nvim_get_current_buf() == bufnr then
    -- Clamp to the inserted content.
    local total = vim.api.nvim_buf_line_count(bufnr)
    caret_line = math.min(caret_line, total - 1)
    local line_text = vim.api.nvim_buf_get_lines(bufnr, caret_line, caret_line + 1, false)[1] or ""
    caret_col = math.min(#line_text, caret_col)
    vim.api.nvim_win_set_cursor(0, { caret_line + 1, caret_col })
  end
end

-- Prompt for a template and request the server to interpolate it.
-- Calls `interpolateFileTemplate` (kotlin-lsp v262.4739.0+).
function M.prompt_and_apply(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local templates = get_templates(opts)
  local order = get_template_order(templates)

  if #order == 0 then
    return
  end

  local function pick(choice)
    if not choice then
      return
    end
    local template = templates[choice]
    if not template then
      return
    end

    local uri = vim.uri_from_bufnr(bufnr)
    lsp.execute_command({
      command = "interpolateFileTemplate",
      arguments = { uri, template },
    }, function(err, result)
      if err then
        vim.notify("Failed to interpolate template: " .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end
      if type(result) ~= "string" or result == "" then
        return
      end
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) and buffer_is_empty(bufnr) then
          apply_content(bufnr, result)
        end
      end)
    end)
  end

  if #order == 1 then
    pick(order[1])
    return
  end

  vim.ui.select(order, { prompt = "Kotlin file template:" }, pick)
end

function M.setup(opts)
  opts = opts or {}

  if opts.file_templates and opts.file_templates.enabled == false then
    return
  end

  vim.api.nvim_create_user_command("KotlinNewFromTemplate", function()
    M.prompt_and_apply(vim.api.nvim_get_current_buf(), opts)
  end, { desc = "Insert a Kotlin file template into the current buffer" })

  local augroup = vim.api.nvim_create_augroup("KotlinFileTemplates", { clear = true })

  -- Mark new Kotlin files so the LspAttach handler knows to prompt for a template
  -- once the server is ready. We can't run interpolateFileTemplate before attach.
  vim.api.nvim_create_autocmd("BufNewFile", {
    group = augroup,
    pattern = "*.kt",
    callback = function(args)
      if buffer_is_empty(args.buf) then
        vim.b[args.buf].kotlin_pending_template = true
      end
    end,
    desc = "Mark new Kotlin file for templating",
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = augroup,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not (client and client.name == "kotlin_ls") then
        return
      end
      if not vim.b[args.buf].kotlin_pending_template then
        return
      end
      vim.b[args.buf].kotlin_pending_template = nil

      if not buffer_is_empty(args.buf) then
        return
      end

      M.prompt_and_apply(args.buf, opts)
    end,
    desc = "Prompt for Kotlin file template on first LSP attach",
  })
end

return M
