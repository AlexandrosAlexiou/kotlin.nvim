local function setup()
  -- Guard to prevent multiple initializations
  if vim.g.kotlin_ls_initialized then
    return
  end
  vim.g.kotlin_ls_initialized = 1

  -- Setup autocommands
  require("kotlin.autocommands").setup_autocommands()

  -- LSP configuration
  vim.lsp.config.kotlin_ls = {
    cmd = { "kotlin-ls", "--stdio" },
    filetypes = { "kotlin" },
    root_markers = {
      "build.gradle",
      "build.gradle.kts",
      "pom.xml",
    },
  }

  vim.lsp.enable("kotlin_ls")
end

local M = {
  setup = setup,
  settings = {
    jdt_uri_timeout_ms = 5000,
  },
}

return M
