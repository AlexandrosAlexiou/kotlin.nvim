local M = {}

local function is_directory(path)
  if not path or path == "" then
    return false
  end
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == "directory"
end

local function is_kotlin_file()
  local ft = vim.bo.filetype
  return ft == "kotlin"
end

function M.setup()
  local group = vim.api.nvim_create_augroup("KotlinFolderHandler", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    pattern = "oil://*",
    callback = function(args)
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
          if #lines <= 1 and (not lines[1] or lines[1] == "") then
            vim.cmd("edit!")
          end
        end
      end, 100)
    end,
  })

  local methods = { "textDocument/definition", "textDocument/typeDefinition", "textDocument/declaration" }
  local original_handlers = {}

  for _, method in ipairs(methods) do
    original_handlers[method] = vim.lsp.handlers[method]

    vim.lsp.handlers[method] = function(err, result, ctx, config)
      if not is_kotlin_file() or not result then
        return original_handlers[method](err, result, ctx, config)
      end

      local function handle_location(location)
        local uri = location.uri or location.targetUri
        if uri then
          local path = vim.uri_to_fname(uri)
          if is_directory(path) then
            vim.schedule(function()
              local ok, oil = pcall(require, "oil")
              if ok then
                oil.open(path)
              else
                vim.notify("oil.nvim not found!", vim.log.levels.ERROR)
              end
            end)
            return true
          end
        end
        return false
      end

      if type(result) == "table" then
        if result.uri or result.targetUri then
          if handle_location(result) then
            return
          end
        else
          local file_results = {}
          local found_directory = false
          for _, loc in ipairs(result) do
            if not handle_location(loc) then
              table.insert(file_results, loc)
            else
              found_directory = true
            end
          end

          if #file_results > 0 then
            result = file_results
          elseif found_directory then
            return
          end
        end
      end

      return original_handlers[method](err, result, ctx, config)
    end
  end
end

return M
