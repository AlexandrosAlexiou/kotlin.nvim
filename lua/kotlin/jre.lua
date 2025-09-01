local M = {}

M.minimum_supported_jre_version = 21

function M.is_supported_version(java_bin)
  local cmd = '"' .. java_bin .. '" -version 2>&1'
  local handle = io.popen(cmd)

  if not handle then
    return false
  end

  local version_output = handle:read("*a")
  handle:close()

  local major_version = nil

  local version_match = version_output:match('version%s+"(%d+)[%.%d_]*')

  if version_match then
    major_version = tonumber(version_match)
  else
    local old_version_match = version_output:match('version%s+"1%.(%d+)[%.%d_]*')
    if old_version_match then
      major_version = tonumber(old_version_match)
    end
  end

  if not major_version then
    return false
  end

  return major_version >= M.minimum_supported_jre_version
end

return M
