Troubleshooting
===============

Start with `:checkhealth kotlin`. It shows the server that will be launched,
its build and licence status, and which capabilities a running server
advertises.

- [The server does not start: build expired](#the-server-does-not-start-build-expired)
- [Inlay hints are missing or settings are ignored](#inlay-hints-are-missing-or-settings-are-ignored)
- [The project import fails](#the-project-import-fails)
- [Stale or broken analysis](#stale-or-broken-analysis)
- [Extra brackets after completion](#extra-brackets-after-completion)
- [Logs](#logs)

<br>

## The server does not start: build expired

kotlin-lsp builds carry a time-limited licence. When it lapses, the launcher
exits with code 7 and the server never starts. kotlin.nvim reports this, and
`:checkhealth kotlin` shows the expiry date.

| Build | Expires |
|---|---|
| v263.4702.0 | 2026-10-08 |
| v263.6379.0 | 2026-10-30 |

Update kotlin-lsp before then: `:MasonInstall kotlin-lsp`, or a newer build from
the [releases](https://github.com/Kotlin/kotlin-lsp/releases).

<br>

## Inlay hints are missing or settings are ignored

kotlin_lsp was most likely started by mason-lspconfig or nvim-lspconfig instead
of kotlin.nvim. That client lacks the `workspace/configuration` handler the
server needs for inlay hints, and it never sees kotlin.nvim's options. Exclude
it:

```lua
require("mason-lspconfig").setup {
    automatic_enable = { exclude = { "kotlin_lsp" } },
}
```

and do not call `vim.lsp.enable("kotlin_lsp")` yourself.

<br>

## The project import fails

Open `:KotlinBuildLog` for the Gradle/Maven output.

- **Several build systems in one folder.** The server blocks the import and
  kotlin.nvim notifies you. Set `build_tool = "gradle"` (or `"maven"`) and run
  `:KotlinReloadWorkspace`.
- **Maven cannot see your environment.** The server clears the environment for
  Maven. Pass what the build needs through the project's `env`
  (see [configuration.md](configuration.md#projects-and-build-tools)).
- **Maven cannot reach your repository** (for example a TLS error against a
  corporate mirror). The server runs Maven on its own bundled runtime, which
  may not trust your company's certificates. If your local repository already
  has the dependencies, import offline:
  `projects = { { type = "maven", path = ".", offline = true } }`
  (v263.6379.0+).
- **Wrong JDK APIs.** Set `jdk_for_symbol_resolution` to the project's target
  JDK.

<br>

## Stale or broken analysis

- `:KotlinReloadWorkspace` re-imports the project and keeps the indexes.
- `:KotlinRestart` restarts the server.
- `:KotlinCleanWorkspace` stops the server, deletes this project's state
  directory and the index directory the server reported, and restarts. The
  next start re-indexes. Other projects are not touched.

Upgrading from a kotlin.nvim version that named state directories `<name>`
only (without the hash): the old directories under
`~/.cache/kotlin-lsp-workspaces/` are no longer used and can be deleted.

If kotlin-lsp cannot handle a project at all, disable it there with a
`.disable-kotlin-lsp` file
(see [configuration.md](configuration.md#disabling-the-server-for-a-project)).

<br>

## Extra brackets after completion

The server inserts brackets itself. Turn off your completion engine's
auto-brackets for Kotlin, see [features.md](features.md#completion).

<br>

## Logs

`:KotlinShowLogs` opens the server log of the current project and Neovim's LSP
log. The server log lives at
`~/.cache/kotlin-lsp-workspaces/<name>-<hash>/system/log/intellij-server.log`.

For protocol-level detail, raise Neovim's LSP log level before reproducing:

```lua
vim.lsp.log.set_level("debug")
```

`:KotlinExportWorkspaceToJson` writes the imported workspace model to
`workspace.json`, which helps when reporting an import problem.
