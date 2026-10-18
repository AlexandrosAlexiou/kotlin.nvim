Installation
============

kotlin.nvim needs two things: the plugin itself and a [kotlin-lsp][kotlin-lsp]
server build. The server bundles its own Java runtime (JBR), so no JDK is
needed to *run* it.

<br>

## Plugin

### lazy.nvim

```lua
{
    "AlexandrosAlexiou/kotlin.nvim",
    ft = { "kotlin" },
    dependencies = {
        "mason.nvim",
        "mason-lspconfig.nvim",
        "oil.nvim",
        "trouble.nvim",
    },
    opts = {},
}
```

`opts` takes every option described in [configuration.md](configuration.md).
`opts = {}` is a working setup: the plugin finds the server, picks the project
root and starts kotlin-lsp when you open a Kotlin file.

### Dependencies

| Plugin | Used for |
|---|---|
| [mason.nvim][mason] | Installing kotlin-lsp (optional: see [manual installation](#manual)) |
| [mason-lspconfig.nvim][mason-lspconfig] | Mason LSP integration |
| [oil.nvim][oil] | Opening package folders from "go to definition" on a `package` declaration, and moving files with references updated |
| [trouble.nvim][trouble] | `:KotlinSymbols` and `:KotlinWorkspaceSymbols` |
| [nvim-dap][nvim-dap] | Optional. Running and debugging, see [debugging.md](debugging.md) |

nvim-dap is not a kotlin.nvim dependency. Install and configure it separately
(signs, keymaps, optionally nvim-dap-ui); kotlin.nvim only registers a `kotlin`
adapter on top. Without nvim-dap the debugging features are skipped and
everything else works.

> [!important]
> **Using mason-lspconfig?** Do not let it auto-enable `kotlin_lsp`. Its
> `automatic_enable` starts kotlin_lsp from nvim-lspconfig's default config
> *before* kotlin.nvim configures it. That client lacks the
> `workspace/configuration` handler kotlin-lsp needs, so **all inlay hints
> disappear** and kotlin.nvim's settings are ignored. Exclude kotlin_lsp and let
> kotlin.nvim start it:
>
> ```lua
> require("mason-lspconfig").setup {
>     automatic_enable = { exclude = { "kotlin_lsp" } },
> }
> ```
>
> The same applies to a plain [nvim-lspconfig][lspconfig] setup: do not call
> `vim.lsp.enable("kotlin_lsp")` yourself.

<br>

## Language server

### Mason (recommended)

```vim
:MasonInstall kotlin-lsp
```

Mason installs the platform-specific build with the bundled runtime.

### Manual

Download a standalone build from the [kotlin-lsp releases][releases] and point
`KOTLIN_LSP_DIR` at it. The variable is used when Mason has no kotlin-lsp
package.

```sh
export KOTLIN_LSP_DIR=/path/to/kotlin-lsp
```

The directory must contain the `bin/intellij-server` launcher:

```
$KOTLIN_LSP_DIR/
├── bin/
│   └── intellij-server    (intellij-server.exe on Windows)
└── lib/
    └── ...
```

Run `:checkhealth kotlin` to confirm the launcher is found and to see when the
build expires (see [troubleshooting](troubleshooting.md#the-server-does-not-start-build-expired)).

<br>

## Supported kotlin-lsp versions

kotlin.nvim launches the server through `bin/intellij-server`, which needs
kotlin-lsp **v262.4739.0** or later. Newer server features are used when the
server offers them:

| kotlin-lsp | Adds |
|---|---|
| v262.4739.0 | Minimum. Call hierarchy, LSP folding, file templates, the `build_tool` option, type definition / implementation, Maven import |
| v263.4702.0 | Intentions that need the editor (menus, clipboard, follow-up rename), run/debug code lenses and launching, `:KotlinReloadWorkspace`, the `projects` option, type hierarchy, live-template completions |
| v263.6379.0 | Extract / Inline local variable, conflict prompts for refactorings, Maven `profiles` / `offline` / `download_additional_artifacts`, `--enable-preview` added to launches automatically |
| v263.7084.0 | Stepping inside scope functions (`let`, `also`, `with`, …), coroutine async stack traces in launched programs |

<br>

## Migrating from v1

**v2 dropped the legacy launcher.** The plugin starts the server only through
`bin/intellij-server` (kotlin-lsp v262.4739.0+). The old `kotlin-lsp.sh` /
`kotlin-lsp.cmd` shims and the `java -cp lib/* …` fallback are gone.

1. Update kotlin-lsp to v262.4739.0 or later (`:MasonInstall kotlin-lsp`).
2. Remove `jre_path` from your setup. The option no longer exists, since
   `bin/intellij-server` manages its own runtime. JVM flags still go through
   `jvm_args`.
3. Run `:checkhealth kotlin` to confirm the launcher is detected.

> [!tip]
> Pinned to an older kotlin-lsp? Stay on the v1 line:
> `{ "AlexandrosAlexiou/kotlin.nvim", version = "v1.4.0" }`.

[kotlin-lsp]: https://github.com/Kotlin/kotlin-lsp/
[releases]: https://github.com/Kotlin/kotlin-lsp/releases
[mason]: https://github.com/mason-org/mason.nvim
[mason-lspconfig]: https://github.com/mason-org/mason-lspconfig.nvim
[lspconfig]: https://github.com/neovim/nvim-lspconfig
[oil]: https://github.com/stevearc/oil.nvim
[trouble]: https://github.com/folke/trouble.nvim
[nvim-dap]: https://github.com/mfussenegger/nvim-dap
