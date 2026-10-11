kotlin.nvim &mdash; JetBrains' Kotlin language server in Neovim
================================================================

[<img alt="github" src="https://img.shields.io/badge/github-AlexandrosAlexiou/kotlin.nvim-8da0cb?style=for-the-badge&labelColor=555555&logo=github" height="20">](https://github.com/AlexandrosAlexiou/kotlin.nvim)
[<img alt="neovim" src="https://img.shields.io/badge/neovim-0.11+-57A143?style=for-the-badge&labelColor=555555&logo=neovim" height="20">](https://neovim.io/)
[<img alt="kotlin-lsp" src="https://img.shields.io/badge/kotlin--lsp-v263.6379.0-7F52FF?style=for-the-badge&labelColor=555555&logo=kotlin" height="20">](https://github.com/Kotlin/kotlin-lsp/releases)
[<img alt="license" src="https://img.shields.io/github/license/AlexandrosAlexiou/kotlin.nvim?style=for-the-badge" height="20">](LICENSE.txt)

This plugin runs [kotlin-lsp], JetBrains' official Kotlin language server, in
Neovim and supplies the editor side the server was written for. The server is
developed together with the JetBrains VS Code extension and leans on that
client: it asks for configuration on the fly, inserts completions through
commands, drives refactorings through its own `intellij/*` messages and
resolves program launches for the debugger. A plain `vim.lsp.enable()` client
starts it, but inlay hints stay empty, completions land twice and the
intentions that need the editor are never offered.

kotlin.nvim fills those gaps so Neovim gets what VS Code gets: IntelliJ's
completion, inspections, intentions and refactorings, inlay hints, run and
debug through nvim-dap, and a per-project server that keeps its indexes apart
from every other project.

```lua
-- lazy.nvim
{
    "AlexandrosAlexiou/kotlin.nvim",
    ft = { "kotlin" },
    dependencies = { "mason.nvim", "mason-lspconfig.nvim", "oil.nvim", "trouble.nvim" },
    opts = {},
}
```

```vim
:MasonInstall kotlin-lsp
```

*Requires Neovim 0.11+ and kotlin-lsp v262.4739.0+ (v263.6379.0 recommended)*<br>
*[Release notes](https://github.com/AlexandrosAlexiou/kotlin.nvim/releases)*

<br>

## Documentation

| | |
|---|---|
| [Installation](docs/installation.md) | Plugin managers, dependencies, installing the server, supported versions, migrating from v1 |
| [Configuration](docs/configuration.md) | Every option, per-project `.kotlin-lsp.lua`, inlay hints, build tools and multi-project import |
| [Features](docs/features.md) | Commands, completion, intentions and refactorings, library sources, Java files, workspace management |
| [Running and debugging](docs/debugging.md) | Code lenses, `:KotlinRunMain`, launch configurations, `launch.json`, attaching |
| [Troubleshooting](docs/troubleshooting.md) | Expired builds, missing inlay hints, import failures, logs |

The same material is available inside Neovim as `:help kotlin.nvim.contents`.

<br>

## Overview

When you open a Kotlin file, kotlin.nvim finds the project root, starts
kotlin-lsp through its `bin/intellij-server` launcher (the server brings its
own Java runtime) and gives the project its own state directory, so indexes
and caches are never shared between projects. Mason's kotlin-lsp package is
used when present, otherwise the build that `KOTLIN_LSP_DIR` points at.

Standard LSP features need nothing extra: diagnostics, hover, go to
definition, references, rename, symbols, formatting with IntelliJ's code style,
semantic highlighting, folding, call and type hierarchy. On top of them the
plugin implements what the server expects from its own client:

- **Completion that inserts once.** The server inserts the text, imports and
  caret itself through a command. kotlin.nvim keeps Neovim from inserting it
  a second time, in the built-in completion, nvim-cmp and blink.cmp alike.

- **Intentions and refactorings.** kotlin.nvim declares itself a JetBrains
  client, which unlocks the intentions that need a menu, the clipboard, a
  conflict prompt or a follow-up rename, including Extract and Inline local
  variable.

- **Inlay hints.** The server asks for its hint settings on every request.
  kotlin.nvim answers from the `inlay_hints` option.

- **Running and debugging.** Run and Debug lenses above `main`,
  `:KotlinRunMain`, `:KotlinDebugMain` and `:KotlinDebug`. The server decides
  whether to launch through Gradle or a plain JVM, and VS Code `launch.json`
  files work as they are.

- **Library sources.** `jar:` and `jrt:` locations open as read-only buffers
  with hover and navigation still working inside them.

- **Workspace management.** Re-import on build-file save, a build log, and
  `:KotlinCleanWorkspace` to reset one project's indexes.

<br>

## Example

A configuration for a larger Gradle project, with a project-specific JDK in a
second repository:

```lua
require("kotlin").setup {
    root_markers = { "settings.gradle.kts", "gradlew", ".git" },
    jvm_args = { "-Xmx8g" },
    inlay_hints = {
        enabled = true,
        parameters_compiled = false,
        call_chains = true,
    },
    reload_workspace = { on_build_file_save = "always" },
    dap = { console = "internalConsole" },
}
```

```lua
-- legacy-service/.kotlin-lsp.lua
return {
    jdk_for_symbol_resolution = "/usr/lib/jvm/java-11-openjdk",
    build_tool = "maven",
}
```

A project's `.kotlin-lsp.lua` overrides the global options for that project.
Every option is listed in [docs/configuration.md](docs/configuration.md).

<br>

## Credits

kotlin.nvim borrows ideas from [nvim-jdtls], [rustaceanvim] and JetBrains'
[kotlin-vscode] extension, and integrates with [oil.nvim], [trouble.nvim] and
[nvim-dap].

[kotlin-lsp]: https://github.com/Kotlin/kotlin-lsp/
[kotlin-vscode]: https://github.com/Kotlin/kotlin-lsp/tree/main/kotlin-vscode
[nvim-jdtls]: https://github.com/mfussenegger/nvim-jdtls
[rustaceanvim]: https://github.com/mrcjkb/rustaceanvim
[oil.nvim]: https://github.com/stevearc/oil.nvim
[trouble.nvim]: https://github.com/folke/trouble.nvim
[nvim-dap]: https://github.com/mfussenegger/nvim-dap

<br>

#### License

<sup>
Licensed under the <a href="LICENSE.txt">GNU General Public License v3.0</a>.
</sup>
