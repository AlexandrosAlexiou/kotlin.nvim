---@mod kotlin.semantic_tokens Refresh semantic tokens once indexing ends
---
--- A semanticTokens request answered while the server is still importing or
--- indexing yields a degraded result (an error, an empty list, or tokens
--- computed against unresolved code). Neovim caches it for the document
--- version and only re-requests on an edit, so buffers opened during indexing
--- keep stale highlighting. The server reports indexing through $/progress
--- ("Indexing") but never sends workspace/semanticTokens/refresh afterwards:
--- invoke Neovim's built-in refresh handler ourselves when that progress ends.
--- Unlike force_refresh it keeps the old highlights until fresh ones arrive.

local M = {}

-- client_id -> progress token -> title
local progress = {}

local installed = false

--- Idempotent.
function M.setup()
  if installed then
    return
  end
  installed = true
  vim.api.nvim_create_autocmd("LspProgress", {
    group = vim.api.nvim_create_augroup("KotlinSemanticTokens", { clear = true }),
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client or client.name ~= "kotlin_lsp" then
        return
      end
      local params = ev.data.params
      local value = params.value or {}
      local by_token = progress[client.id] or {}
      progress[client.id] = by_token
      if value.kind == "begin" then
        by_token[params.token] = value.title
      elseif value.kind == "end" then
        local title = by_token[params.token]
        by_token[params.token] = nil
        if title == "Indexing" then
          pcall(vim.lsp.handlers["workspace/semanticTokens/refresh"], nil, nil, { client_id = client.id })
        end
      end
    end,
    desc = "Refresh kotlin-lsp semantic tokens once indexing ends",
  })
end

return M
