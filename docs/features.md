Features
========

Everything kotlin-lsp offers through standard LSP (completion, diagnostics,
hover, navigation, references, rename, formatting, symbols, semantic
highlighting) works through Neovim's built-in client. This page covers the
commands kotlin.nvim adds and the places where it supplies what the server
expects from the VS Code client.

- [Commands](#commands)
- [Completion](#completion)
- [Intentions and refactorings](#intentions-and-refactorings)
- [Moving files](#moving-files)
- [Library sources](#library-sources)
- [Java files](#java-files)
- [Semantic highlighting](#semantic-highlighting)
- [Workspace, build log and per-project state](#workspace-build-log-and-per-project-state)
- [File templates and package navigation](#file-templates-and-package-navigation)

<br>

## Commands

| Command | Description |
|---|---|
| `:KotlinCodeActions` | Code actions at the cursor (intentions, refactorings, quick fixes) |
| `:KotlinQuickFix` | Quick fixes for the diagnostics on the current line |
| `:KotlinRename` | Rename the symbol under the cursor across the project |
| `:KotlinReferences` | Find references |
| `:KotlinTypeDefinition` | Go to the type definition |
| `:KotlinImplementation` | Go to implementations |
| `:KotlinIncomingCalls` / `:KotlinOutgoingCalls` | Call hierarchy |
| `:KotlinSupertypes` / `:KotlinSubtypes` | Type hierarchy |
| `:KotlinSymbols` | Document outline (trouble.nvim) |
| `:KotlinWorkspaceSymbols` | Workspace symbol search (trouble.nvim) |
| `:KotlinOrganizeImports` | Organize imports |
| `:KotlinFormat` | Format with IntelliJ's formatter |
| `:KotlinInlayHintsToggle` | Toggle inlay hints for the buffer |
| `:KotlinHintsToggle` | Toggle HINT-severity diagnostics |
| `:KotlinNewFromTemplate` | Apply an IntelliJ file template to the buffer |
| `:KotlinRunMain [args]` | Run `main` of the current file (nvim-dap) |
| `:KotlinDebugMain [args]` | Debug `main` of the current file (nvim-dap) |
| `:KotlinDebug [port]` | Attach the debugger to a JVM (JDWP, default 5005) |
| `:KotlinReloadWorkspace` | Re-import the project without restarting the server |
| `:KotlinRestart` | Restart the server |
| `:KotlinCleanWorkspace` | Delete this project's server state and indexes, then restart |
| `:KotlinBuildLog` | Import and build output |
| `:KotlinShowLogs` | The project's server log and Neovim's LSP log |
| `:KotlinExportWorkspaceToJson` | Write the imported workspace model to `workspace.json` |

kotlin.nvim sets no keymaps. An example set:

```lua
local map = function(lhs, cmd, desc) vim.keymap.set("n", lhs, cmd, { desc = desc }) end
map("<leader>ka", "<cmd>KotlinCodeActions<cr>", "Kotlin code actions")
map("<leader>kq", "<cmd>KotlinQuickFix<cr>", "Kotlin quick fix")
map("<leader>kt", "<cmd>KotlinTypeDefinition<cr>", "Go to type definition")
map("<leader>ki", "<cmd>KotlinImplementation<cr>", "Go to implementation")
map("<leader>ko", "<cmd>KotlinOrganizeImports<cr>", "Organize imports")
map("<leader>kf", "<cmd>KotlinFormat<cr>", "Format buffer")
map("<leader>ks", "<cmd>KotlinSymbols<cr>", "Document symbols")
map("<leader>kr", "<cmd>KotlinReferences<cr>", "Find references")
map("<leader>kn", "<cmd>KotlinRename<cr>", "Rename symbol")
map("<leader>kh", "<cmd>KotlinInlayHintsToggle<cr>", "Toggle inlay hints")
map("<leader>kl", "<cmd>KotlinShowLogs<cr>", "Kotlin LSP logs")
map("<leader>kd", "<cmd>KotlinDebug<cr>", "Attach debugger")
```

<br>

## Completion

kotlin-lsp's completion items do not contain the text to insert. Each carries
an empty `textEdit` plus a `jetbrains.kotlin.completion.apply` command, and the
server inserts the real text afterwards with `workspace/applyEdit` and
`window/showDocument`. VS Code's client inserts nothing and lets the command do
the work. Neovim's completion engines insert the item text *and* run the
command, so accepting `App` used to produce `Ap|p`.

kotlin.nvim turns the client's own insertion into a no-op and keeps the
command, so the server does the whole insertion: text, **auto-import**,
parentheses and caret. This works in the built-in completion, nvim-cmp and
blink.cmp, since all of them run the item's command. Live templates (`main`,
`sout`, `fori`, …) go through the same path: accepting `sout` gives
`println()` with the caret inside the parentheses.

> [!tip]
> The server inserts brackets itself (`firstOrNull { }`), so turn off your
> engine's auto-brackets for Kotlin or you get an extra `()`. For blink.cmp:
>
> ```lua
> completion = { accept = { auto_brackets = { blocked_filetypes = { "kotlin" } } } }
> ```
>
> For nvim-cmp with nvim-autopairs, add `kotlin` to the `confirm_done`
> handler's `filetypes` blocklist.

<br>

## Intentions and refactorings

kotlin-lsp exposes most of IntelliJ's Kotlin intentions and quick fixes as code
actions, including the **Extract to local variable** and **Inline local
variable** refactorings (v263.6379.0+). Some of them need the editor's help, so
the server only offers them to a client that declares the JetBrains protocol
extensions. kotlin.nvim declares them and implements:

| Server message | What happens |
|---|---|
| `intellij/chooseAction` | A "choose one" menu, shown with `vim.ui.select`; the pick is run on the server |
| `intellij/showConflicts` | A refactoring found problems and asks whether to continue. Shown with `vim.ui.select`; picking a conflict opens its code, closing the menu cancels |
| `intellij/copyToClipboard` | Text copied to the `+` and `"` registers |
| `intellij/runEditorCommand` | `editor.action.rename` → `vim.lsp.buf.rename()` (e.g. naming the extracted variable), `editor.action.triggerSuggest` → completion, `editor.action.triggerParameterHints` → signature help |

kotlin.nvim also asks for lazy intentions: the code-action list only describes
each fix, and the server computes the edit when you pick one.

Two server quirks are handled along the way:

- The server labels its edits with its own count of document changes rather
  than the version Neovim sent, so Neovim would treat every edit after the first
  change in a buffer as stale and silently drop it. kotlin.nvim clears that
  version before applying the edit.
- Hover text can contain "Go to Super Method"-style links that only VS Code can
  follow. kotlin.nvim strips the link and keeps the label.

<br>

## Moving files

The server implements `workspace/willRenameFiles`: when a Kotlin file or
package moves, it updates the `package` line, imports and references. Neovim
does not send that request on its own, but file managers do, for example
[oil.nvim](https://github.com/stevearc/oil.nvim) with `lsp_file_methods` or
nvim-lsp-file-operations. If a move would break code (for example a
declaration clashing with one in the target package), the server refuses it
and reports why.

<br>

## Library sources

Go-to-definition into a dependency or the JDK returns `jar:` or `jrt:`
locations. kotlin.nvim fills such a buffer through the server's `decompile`
command (attached sources when the build tool downloaded them, decompiled
bytecode otherwise), makes it read-only and attaches the kotlin-lsp client to
it, as the VS Code client does. Hover, further navigation and semantic
highlighting therefore work inside `kotlin-stdlib-…-sources.jar!/…/Collections.kt`
too. Such buffers are re-attached after a server restart.

<br>

## Java files

The "Kotlin by JetBrains" server reads Java code for Kotlin analysis and lets
you navigate from Kotlin into Java, but it provides no features *inside* Java
files (definition, references, symbols and completion return nothing there).
Use jdtls or the "Java and Kotlin by IntelliJ IDEA" server for Java editing.

kotlin.nvim still attaches to Java buffers of a project whose server is already
running, as the VS Code client does, so unsaved Java edits reach Kotlin
analysis immediately. Opening a Java file alone never starts kotlin-lsp.
`java_files = false` turns this off. If jdtls runs alongside, format through it
by name (`vim.lsp.buf.format({ name = "jdtls" })`), since both clients
advertise formatting.

<br>

## Semantic highlighting

The server reports indexing through `$/progress` but never asks the client to
refresh semantic tokens afterwards, so buffers opened during indexing kept
degraded highlighting until the next edit. kotlin.nvim refreshes them when
indexing ends.

<br>

## Workspace, build log and per-project state

**Reload and restart.** `:KotlinReloadWorkspace` asks the server to re-import
the project, resending the initialization options; the process and its
indexes stay. Saving `build.gradle(.kts)`, `settings.gradle(.kts)` or `pom.xml`
offers the same (`reload_workspace.on_build_file_save = "ask"`), does it
without asking (`"always"`) or does nothing (`"never"`). `:KotlinRestart`
stops and starts the server.

**Build log.** `:KotlinBuildLog` shows Gradle/Maven import output and the
builds run before a launch. Import start, failure and success are also
notified, and so is a folder whose import is blocked because it contains more
than one build system.

**Per-project state.** Each project root gets its own server state directory,
`~/.cache/kotlin-lsp-workspaces/<name>-<hash>`
(`%LOCALAPPDATA%\kotlin-lsp-workspaces\<name>-<hash>` on Windows), so two
projects never share indexes, logs or caches, and two projects with the same
directory name do not collide. The server keeps its index inside that directory
and reports where (v263.4702.0+). `:KotlinCleanWorkspace` deletes that
directory and the reported index directory, nothing else, and restarts.

<br>

## File templates and package navigation

**File templates.** Creating a new `.kt` file offers IntelliJ's templates
(Class, File, Interface, Data Class, Enum, Annotation, Object), filled in by
the server with the package and name. `:KotlinNewFromTemplate` applies one to
the current buffer. Templates are configurable, see
[configuration.md](configuration.md#all-options).

**Package navigation.** Go-to-definition on a `package` declaration opens that
package's folder in oil.nvim.

**Workspace export.** `:KotlinExportWorkspaceToJson` writes the model the
server imported to `workspace.json`, which is useful when reporting import
problems.
