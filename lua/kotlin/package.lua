local M = {}

local function is_directory(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == "directory"
end

function M.setup()
  local group = vim.api.nvim_create_augroup("KotlinDirIntercept", { clear = true })

  vim.api.nvim_create_autocmd("BufNew", {
    group = group,
    callback = function(args)
      local bufname = vim.api.nvim_buf_get_name(args.buf)
      if bufname and bufname ~= "" and is_directory(bufname) then
        vim.schedule(function()
          local prev_buf = vim.fn.bufnr("#")
          local prev_ft = vim.api.nvim_buf_get_option(prev_buf, "filetype") or ""

          if prev_ft == "kotlin" then
            local ok, oil = pcall(require, "oil")
            if ok then
              local open_ok, open_err = pcall(oil.open, bufname)
              if not open_ok then
                vim.notify("Failed to open with oil: " .. (open_err or "unknown"), vim.log.levels.ERROR)
              end
            else
              vim.notify("oil.nvim not found", vim.log.levels.WARN)
            end
          end
        end)
      end
    end,
  })

  -- Fix for oil buffers that get stuck in modified state
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "oil://*",
    callback = function()
      vim.bo.modified = false
    end,
  })
end

return M
