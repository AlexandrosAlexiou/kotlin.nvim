---@mod kotlin.hover Clean up VS Code-only markup in hover responses
---
--- kotlin-lsp embeds navigation links such as "Go to Super Method" in hover
--- markdown as `[label](command:jetbrains.navigateToLocation?...)`. Only VS
--- Code can run `command:` links, so in Neovim they render as dead links.
--- This strips the link and keeps the label.

local M = {}

local function strip_command_links(text)
  -- [label](command:...) -> label
  return (text:gsub("%[([^%]]-)%]%(command:[^%)]*%)", "%1"))
end

--- Rewrite `result.contents` in place. Handles MarkupContent, MarkedString
--- and arrays of MarkedString.
---@param result lsp.Hover?
function M.patch(result)
  if type(result) ~= "table" or result.contents == nil then
    return
  end
  local contents = result.contents
  if type(contents) == "string" then
    result.contents = strip_command_links(contents)
  elseif type(contents) == "table" then
    if type(contents.value) == "string" then
      contents.value = strip_command_links(contents.value)
    else
      for i, part in ipairs(contents) do
        if type(part) == "string" then
          contents[i] = strip_command_links(part)
        elseif type(part) == "table" and type(part.value) == "string" then
          part.value = strip_command_links(part.value)
        end
      end
    end
  end
end

return M
