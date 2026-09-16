<!-- markdownlint-disable -->
<div align="center">
  <a href="https://github.com/AlexandrosAlexiou/kotlin.nvim">
    <img src="./.github/kodee.png" alt="kotlin.nvim" width="150">
  </a>
  <h1 align="center">
    kotlin.nvim
  </h1>
  <p>
    <br />
    <strong>
      Extensions for JetBrains'
      <a href="https://github.com/Kotlin/kotlin-lsp/">Kotlin Language Server (kotlin-lsp)</a>
      support in <a href="https://neovim.io/">Neovim</a><br />
      (>=0.11.0)
    </strong>
  </p>

  <p>
    <a href="./doc/kotlin.nvim.txt"><strong>Explore the docs »</strong></a>
    <br /><br />
    <a href="https://github.com/AlexandrosAlexiou/kotlin.nvim/issues/new?assignees=&labels=bug&projects=&template=bug_report.yml">Report Bug</a>
    ·
    <a href="https://github.com/AlexandrosAlexiou/kotlin.nvim/discussions/new?category=ideas">Request Feature</a>
    ·
    <a href="https://github.com/AlexandrosAlexiou/kotlin.nvim/discussions/new?category=q-a">Ask Question</a>
  </p>

  <br />

  [![Neovim][neovim-shield]][neovim-url]
  [![Lua][lua-shield]][lua-url]
  [![Kotlin][kotlin-shield]][kotlin-url]

  [![GPL3 License][license-shield]][license-url]
  [![Issues][issues-shield]][issues-url]
</div>


## 🧩 Extensions

- [x] Library and JDK sources (`jar:` / `jrt:` locations from go-to-definition) open as read-only buffers served by the LSP: hover, navigation and semantic highlighting work inside them
- [x] Java buffers in a project whose server is running are attached too, like the VS Code client, so unsaved Java edits reach Kotlin analysis at once (`java_files = false` to opt out); a Java file alone never starts the server
- [x] Semantic highlighting is refreshed once indexing finishes
- [x] Live-template completions (`main`, `sout`, `fori`, …) work through the same server-driven insertion as ordinary items (kotlin-lsp v263.4702.0+)
- [x] Export workspace to JSON using kotlin-lsp `exportWorkspace` command
- [x] Organize imports with `KotlinOrganizeImports` command
- [x] Format code with `KotlinFormat` command (uses IntelliJ IDEA formatting)
- [x] Toggle diagnostic hints using the `KotlinHintsToggle` command
- [x] Full support for LSP inlay hints with fine-grained configuration
- [x] JDK version specification for symbol resolution
- [x] Support for custom JVM arguments
- [x] Support kotlin-lsp installation from [Mason][6]
- [x] Navigate to package folders from package declarations (opens the folder view with [oil.nvim][11] using LSP "go to definition")
- [x] "Go to Type Definition" and "Go to Implementation" support (kotlin-lsp v262+)
- [x] Call hierarchy ("incoming/outgoing calls") via `KotlinIncomingCalls` / `KotlinOutgoingCalls` (kotlin-lsp v262.4739.0+)
- [x] LSP-driven code folding for Kotlin functions, classes, blocks, imports and multiline comments (kotlin-lsp v262.4739.0+)
- [x] IntelliJ-style file templates (Class, Interface, Data Class, …) via `KotlinNewFromTemplate` and on file creation (kotlin-lsp v262.4739.0+)
- [x] Configurable build-tool importer (`gradle` / `maven`) via the `build_tool` option (kotlin-lsp v262.4739.0+)
- [x] Maven project import support (kotlin-lsp v262+)
- [x] Multi-project import via the `projects` option (monorepos, several independent projects in one workspace) (kotlin-lsp v263.4702.0+)
- [x] IntelliJ intentions and quick fixes that need editor cooperation — "choose one" menus, copy to clipboard, follow-up rename — through the `intellij/*` protocol extensions (kotlin-lsp v263.4702.0+)
- [x] Run and debug `main` functions from code lenses, `:KotlinRunMain` / `:KotlinDebugMain`, nvim-dap configurations or a VS Code `.vscode/launch.json`, through Gradle or a plain JVM launch (kotlin-lsp v263.4702.0+, requires nvim-dap)
- [x] Attach the debugger to a running JVM with `:KotlinDebug`
- [x] `:KotlinReloadWorkspace` re-imports the project without a restart, optionally whenever a build file is saved; `:KotlinRestart` restarts the server (kotlin-lsp v263.4702.0+)
- [x] Build-import output in a `:KotlinBuildLog` buffer, with notifications when an import starts, fails, or is blocked by an ambiguous build system
- [x] Type hierarchy via `KotlinSupertypes` / `KotlinSubtypes` (kotlin-lsp v263.4702.0+)
- [x] Move a Kotlin file with imports and references updated: the server implements `workspace/willRenameFiles`, so renaming/moving in [oil.nvim][11] (`lsp_file_methods`) fixes up the code
- [x] Automatic per-project workspace isolation to prevent LSP conflicts and improve performance
  - Use `KotlinCleanWorkspace` command to delete exactly the index directory the server reports for the current project and restart
- [x] Per-project LSP configuration via `.kotlin-lsp.lua` file
- [x] Per-project LSP disabling via marker file
  - Create a `.disable-kotlin-lsp` file in the project root to prevent the Kotlin LSP from starting (detected automatically by searching upward from the opened file)
- [x] Warns when the kotlin-lsp build has expired: builds carry a time-limited licence and the launcher then exits with code 7. `:checkhealth kotlin` shows the expiry date.

> [!note]
> **Version Requirements:**
> - The plugin launches kotlin-lsp via its `bin/intellij-server` native launcher, which requires kotlin-lsp **v262.4739.0+**. Older builds that only ship the `kotlin-lsp.sh` / `kotlin-lsp.cmd` shim are no longer supported — update your install.
> - Workspace isolation with the `--system-path` parameter requires kotlin-lsp **v0.253.10629** or later.
> - Zero-dependencies platform-specific builds are supported -- no JDK required by default as the language server bundles its own (kotlin-lsp **v261+** or later).
> - Inlay hints require kotlin-lsp **v261+**. The server requests the `jetbrains.kotlin` configuration section dynamically and only renders hints whose option is answered with `true` — kotlin.nvim implements this handler, so the kotlin_lsp client must be started by kotlin.nvim (see the mason-lspconfig note below).
> - Code formatting and organize imports require kotlin-lsp **v0.253+** with IntelliJ IDEA-based formatting support.
> - "Go to Type Definition" and "Go to Implementation" require kotlin-lsp **v262+**.
> - Maven project import is supported starting from kotlin-lsp **v262+**.
> - Call hierarchy, LSP folding, file templates and the `build_tool` option require kotlin-lsp **v262.4739.0+**.
> - Intentions with menus/clipboard/rename, run/debug lenses and launching, `:KotlinReloadWorkspace`, the `projects` option and type hierarchy require kotlin-lsp **v263.4702.0+**.
> - No separate JDK is required to run the server — `bin/intellij-server` uses its own bundled JBR.

## 🚚 Migrating to v2

**v2 drops support for the legacy kotlin-lsp launcher.** The plugin now launches the server exclusively through `bin/intellij-server` (kotlin-lsp **v262.4739.0+**); the old `kotlin-lsp.sh` / `kotlin-lsp.cmd` shims and the manual `java -cp lib/* …` fallback are gone.

To migrate:

1. **Update kotlin-lsp** to v262.4739.0 or later: `:MasonInstall kotlin-lsp` (or `:MasonUpdate`).
2. **Remove `jre_path`** from your `require("kotlin").setup{}` — the option no longer exists (`bin/intellij-server` manages its own bundled JBR). Custom JVM flags still go through `jvm_args`.
3. Run `:checkhealth kotlin` to confirm the `bin/intellij-server` launcher is detected.

> [!tip]
> Need the old shell-script launcher or a custom `jre_path` (e.g. you're pinned to a pre-v262.4739.0 kotlin-lsp)? Stay on the v1 line by pinning the last v1 release in your plugin manager, e.g. lazy.nvim: `{ "AlexandrosAlexiou/kotlin.nvim", version = "v1.4.0" }`.

## 📦 Installation

Install the plugin with your package manager:

**Dependencies:**
- [mason.nvim](https://github.com/williamboman/mason.nvim) - LSP installer
- [mason-lspconfig.nvim](https://github.com/williamboman/mason-lspconfig.nvim) - Mason LSP integration
- [oil.nvim](https://github.com/stevearc/oil.nvim) - File explorer for package navigation (used by "Go to Definition" on package declarations)
- [trouble.nvim](https://github.com/folke/trouble.nvim) - Enhanced quickfix/location list UI (required for `:KotlinSymbols` and `:KotlinWorkspaceSymbols` commands to display document outline and workspace symbols)

**Optional (install and configure separately):**
- Debug Adapter Protocol client ([nvim-dap](https://github.com/mfussenegger/nvim-dap)). Required for `:KotlinDebug`. kotlin.nvim does not install or configure nvim-dap for you — set it up once globally (signs, keymaps, optional UI) and kotlin.nvim will register a `kotlin` adapter on top.

> [!important]
> **Using mason-lspconfig?** Do not let it auto-enable `kotlin_lsp`. mason-lspconfig's `automatic_enable` starts
> kotlin_lsp from nvim-lspconfig's default config *before* kotlin.nvim configures it. That client lacks the `workspace/configuration` handler kotlin-lsp needs, so **all inlay hints disappear** and kotlin.nvim settings are ignored. Exclude kotlin_lsp and let kotlin.nvim start it:
>
> ```lua
> require("mason-lspconfig").setup {
>     automatic_enable = { exclude = { "kotlin_lsp" } },
> }
> ```

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "AlexandrosAlexiou/kotlin.nvim",
    ft = { "kotlin" },
    dependencies = {
        "mason.nvim",
        "mason-lspconfig.nvim",
        "oil.nvim",
        "trouble.nvim",
        -- nvim-dap is NOT a kotlin.nvim dependency. Install and configure it
        -- separately (signs, keymaps, optionally nvim-dap-ui). kotlin.nvim only
        -- registers a `kotlin` adapter and the `:KotlinDebug` command on top.
        -- See the "Debugging Support" section below for details.
    },
    config = function()
        require("kotlin").setup {
            -- Optional: Specify root markers for multi-module projects
            -- Default: { "build.gradle", "build.gradle.kts", "pom.xml", "mvnw" }
            root_markers = {
                "gradlew",
                ".git",
                "mvnw",
                "settings.gradle",
            },

            -- Optional: JDK for symbol resolution (analyzing your Kotlin code)
            -- This is the JDK that your project code will be analyzed against
            -- (the server itself runs on bin/intellij-server's bundled JBR)
            -- Required for: Analyzing JDK APIs, standard library symbols, platform types
            --
            -- Usually should match your project's target JDK version
            -- Examples:
            --   macOS:   "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home"
            --   Linux:   "/usr/lib/jvm/java-17-openjdk"
            --   Windows: "C:\\Program Files\\Java\\jdk-17"
            --   SDKMAN:  os.getenv("HOME") .. "/.sdkman/candidates/java/17.0.8-tem"
            jdk_for_symbol_resolution = nil,  -- Auto-detect from project

            -- Optional: Specify additional JVM arguments for the kotlin-lsp server
            jvm_args = {
                "-Xmx4g",  -- Increase max heap (useful for large projects)
            },

            -- Optional: Configure inlay hints (requires kotlin-lsp v261+)
            -- All settings default to true, set to false to disable specific hints
            inlay_hints = {
                enabled = true,  -- Enable inlay hints (auto-enable on LSP attach)
                parameters = true,  -- Show parameter names
                parameters_compiled = true,  -- Show compiled parameter names
                parameters_excluded = false,  -- Show excluded parameter names
                parameters_context = false,  -- Show context parameter hints
                types_property = true,  -- Show property types
                types_variable = true,  -- Show local variable types
                function_return = true,  -- Show function return types
                function_parameter = true,  -- Show function parameter types
                lambda_return = true,  -- Show lambda return types
                lambda_receivers_parameters = true,  -- Show lambda receivers/parameters
                value_ranges = true,  -- Show value ranges
                kotlin_time = true,  -- Show kotlin.time warnings
                call_chains = false,  -- Show call-chain intermediate types (default false)
            },

            -- Optional: LSP-driven folding (requires kotlin-lsp v262.4739.0+)
            -- Enabled by default; set folding.enabled = false to opt out.
            folding = { enabled = true },

            -- Optional: build-importer preference (requires kotlin-lsp v262.4739.0+)
            -- Mirrors the VSCode `intellij.buildTool` setting:
            --   nil = let the server pick (default)
            --   "gradle" or "maven" = force a specific importer
            --   ""    = none (single-file / no build system)
            -- build_tool = "gradle",

            -- Optional: import several projects from one workspace (kotlin-lsp v263.4702.0+).
            -- Mirrors the VSCode `intellij.projects` setting. `path` is a build file or
            -- project directory, absolute or relative to the workspace root.
            -- projects = {
            --     { type = "gradle", path = "backend" },
            --     { type = "maven", path = "tools/pom.xml", java_home = "/path/to/jdk-17",
            --       env = { MAVEN_OPTS = "-Xmx1g" }, system_properties = { ["skip.tests"] = "true" } },
            -- },

            -- Optional: re-import when a build file (build.gradle(.kts), settings.gradle(.kts),
            -- pom.xml) is saved: "ask" (default), "always" or "never".
            reload_workspace = { on_build_file_save = "ask" },

            -- Optional: run/debug code lenses above `main` functions (kotlin-lsp v263.4702.0+)
            code_lens = {
                enabled = true,
                -- The server titles lenses with VS Code codicons ("$(play) Run"); these are
                -- shown instead (Nerd Font glyphs by default). `icons = false` shows text only.
                -- icons = { play = "", debug = "" },
                align = true, -- draw the lens at the line's indent instead of at `main`
            },

            -- Optional: launching programs (requires nvim-dap)
            dap = {
                console = "integratedTerminal", -- or "internalConsole" (output in the dap REPL)
                build_before_run = true,        -- plain JVM launches: run the server's build command first
                configurations = true,          -- add default entries to dap.configurations.kotlin/java
            },

            -- Optional: attach kotlin_lsp to Java buffers of a project whose server is already
            -- running (the VS Code client does this so unsaved Java edits reach Kotlin analysis
            -- immediately). The Kotlin server offers no Java features itself, and a Java file
            -- alone never starts it. Set false if you want Java buffers left to jdtls only.
            java_files = true,

            -- Optional: JetBrains data sharing / region, as asked by the VS Code extension on first
            -- start. Unset = share nothing. data_sharing: "none" | "anonymous" | "full";
            -- region: "africa" | "americas" | "apac" | "china" | "europe" | "middle_east" | "oceania"
            -- data_sharing = "none",
            -- region = "europe",

            -- Optional: disable the RocksDB write-ahead log of the index (VSCode
            -- `intellij.disableRocksDBWriteAheadLog`)
            -- disable_rocksdb_wal = false,

            -- Optional: file templates for new Kotlin files (requires kotlin-lsp v262.4739.0+)
            -- When you create a new .kt file the plugin asks the server to interpolate the
            -- chosen template. Pass a table of name → Velocity template to override the
            -- defaults (Class, File, Interface, Data Class, Enum, Annotation, Object).
            -- Set { enabled = false } on the table to disable the prompt entirely.
            -- file_templates = {
            --     enabled = true,
            --     -- Class = "package ${PACKAGE_NAME}\n\nclass ${NAME} {\n\t|\n}",
            -- },
        }
    end,
},

```

## 🔧 Per-Project Configuration

Since different projects may target different JDK versions or require different settings, kotlin.nvim supports per-project configuration via a `.kotlin-lsp.lua` file in your project root.

### Example: `.kotlin-lsp.lua`

Create a `.kotlin-lsp.lua` file in your project root:

```lua
-- Project-specific Kotlin LSP configuration
return {
    -- This project targets JDK 21
    jdk_for_symbol_resolution = "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home",

    -- Override inlay hints for this project
    inlay_hints = {
        enabled = false,  -- Disable inlay hints for this specific project
    },

    -- Project-specific JVM args
    jvm_args = {
        "-Xmx2g",  -- Less memory for smaller project
    },
}
```

### How It Works

1. **Global config** in your Neovim setup (applies to all projects)
2. **Project config** in `.kotlin-lsp.lua` (overrides global for that project)
3. Project settings are merged with global settings, with project taking precedence
4. After editing `.kotlin-lsp.lua`, run `:KotlinRestart`. Options that only affect the import (`build_tool`, `projects`, `jdk_for_symbol_resolution`) are picked up by `:KotlinReloadWorkspace` too, which keeps the server and its indexes.

### Common Use Cases

**Multi-project workspace with different JDK targets:**
```
~/projects/
  ├── legacy-app/              # Uses JDK 11
  │   └── .kotlin-lsp.lua      # jdk_for_symbol_resolution = "/path/to/jdk-11"
  └── modern-app/              # Uses JDK 21
      └── .kotlin-lsp.lua      # jdk_for_symbol_resolution = "/path/to/jdk-21"
```

**Project with specific memory requirements:**
```lua
-- .kotlin-lsp.lua for large monorepo
return {
    jvm_args = { "-Xmx8g" },  -- More memory for large codebase
}
```

> [!tip]
> Add `.kotlin-lsp.lua` to your `.gitignore` if settings are developer-specific, or commit it if the entire team should use the same configuration.

### Disabling the LSP for a Project

Since the Kotlin language server is under heavy development, it may not fully support all project types or setups yet. If you run into issues with a specific project, you can disable the LSP for that project by creating a `.disable-kotlin-lsp` marker file in the project root:

```sh
cd /path/to/your/kotlin/project
touch .disable-kotlin-lsp
```

The plugin searches upward from the opened file's directory, so it will find the marker regardless of your current working directory. The file can be empty — only its presence is checked.

> [!tip]
> You can also disable the LSP for a single buffer by setting the buffer-local variable `vim.b.disable_kotlin_lsp = true` before the LSP attaches.

## ✨ Features

### Zero-Dependency Installation

When using the Mason-installed kotlin-lsp (v261+), no separate JDK installation is required. The language server includes platform-specific builds with a bundled JRE, providing a truly zero-dependency setup experience.

### JDK for Code Analysis

kotlin.nvim runs the language server through `bin/intellij-server`, which ships
its own bundled JBR — you do **not** need to install or configure a Java runtime
to *run* the server. The only Java-related option is which JDK your code is
*analyzed* against:

#### `jdk_for_symbol_resolution` - JDK for Code Analysis

**Purpose:** Specifies which JDK should be used to **analyze your Kotlin code** and resolve symbols/APIs.

**When to use:**
- Your project targets a specific Java version (e.g., Java 17 or 21)
- You need code completion for JDK-specific APIs
- You want symbol resolution against a particular JDK's standard library
- Different projects use different JDK versions

**Examples:**
```lua
-- Project targeting Java 17
jdk_for_symbol_resolution = "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home"

-- Project targeting Java 21
jdk_for_symbol_resolution = "/usr/lib/jvm/java-21-openjdk"

-- Per-project configuration (in .kotlin-lsp.lua)
return {
    jdk_for_symbol_resolution = "/path/to/project-specific/jdk"
}
```

**Recommendation:** Set this to match your project's target JDK version for accurate symbol resolution.

### Enhanced Code Completion

The latest kotlin-lsp versions offer significantly improved code completion:
- Suggestion ordering on par with IntelliJ IDEA
- ~30% better completion latency
- More relevant and context-aware suggestions

#### Completion insertion fix

kotlin-lsp does not put the inserted text in its completion items. Each item
carries an empty `textEdit` plus a `jetbrains.kotlin.completion.apply` command,
and the server applies the real text + caret afterwards via `workspace/applyEdit`
and `window/showDocument`. VS Code's client inserts nothing on accept and lets
the command do the work, so it just works there. Neovim frontends (builtin
completion, nvim-cmp, blink.cmp) insert the item text *and* run the command, so
the server's edit lands on top and the caret ends up mid-identifier — accepting
`App` produces `Ap|p`.

kotlin.nvim fixes this automatically by making Neovim behave like the VS Code
client: we turn the client's own insertion into a no-op and keep the apply
command, so the server performs the real insertion. You get the full
behaviour — text, **auto-import**, parentheses and caret — in every completion
engine (builtin completion, nvim-cmp, blink.cmp). No configuration required.

> [!NOTE]
> This relies on the frontend executing the completion item's `command` (builtin,
> nvim-cmp and blink.cmp all do). The proper fix is still upstream returning a
> real `textEdit`.

> [!TIP]
> Since the server inserts brackets itself (e.g. `firstOrNull { }`), disable your
> frontend's client-side auto-brackets for Kotlin or you'll get an extra
> trailing `()`. For blink.cmp:
>
> ```lua
> completion = {
>   accept = { auto_brackets = { blocked_filetypes = { "kotlin" } } },
> }
> ```
>
> For nvim-cmp + nvim-autopairs, add `kotlin` to the `confirm_done` handler's
> `filetypes` blocklist.

### Inlay Hints Support

Full support for LSP inlay hints matching the VSCode extension configuration. All hint types are supported with individual toggles.

#### Quick Start

Minimal configuration (enables all hints with defaults):

```lua
require("kotlin").setup {
    inlay_hints = {
        enabled = true,  -- Auto-enable on LSP attach
    },
}
```

#### All Available Settings

All settings default to `true` except `parameters_excluded`, `parameters_context` and `call_chains`. Only specify settings you want to change:

```lua
require("kotlin").setup {
    inlay_hints = {
        enabled = true,  -- Master switch: enable/disable all inlay hints

        -- Parameter hints (show parameter names in function calls)
        parameters = true,  -- foo(name: "value", age: 42)
        parameters_compiled = true,  -- Show parameter names for compiled code
        parameters_excluded = false,  -- Show hints for excluded parameters (usually false)
        parameters_context = false,  -- Show context parameter hints (usually false)

        -- Type hints (show inferred types)
        types_property = true,  -- val name: String = "foo"
        types_variable = true,  -- val count: Int = 42
        function_return = true,  -- fun foo(): String { }
        function_parameter = true,  -- fun foo(name: String) { }

        -- Lambda hints
        lambda_return = true,  -- { x -> x * 2 }: (Int) -> Int
        lambda_receivers_parameters = true,  -- Show receivers and parameters

        -- Other hints
        value_ranges = true,  -- Show hints for ranges
        kotlin_time = true,  -- Show kotlin.time warnings
        call_chains = false,  -- someList.filter{}.map{}: List<T> at each step (usually false)
    },
}
```

#### Settings Reference

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` | Master switch to enable/disable all inlay hints |
| `parameters` | `true` | Show parameter names in function calls |
| `parameters_compiled` | `true` | Show parameter names for compiled/external functions |
| `parameters_excluded` | `false` | Show parameter names for excluded parameters |
| `parameters_context` | `false` | Show context parameter hints |
| `types_property` | `true` | Show type hints for properties |
| `types_variable` | `true` | Show type hints for local variables |
| `function_return` | `true` | Show return type hints for functions |
| `function_parameter` | `true` | Show type hints for function parameters |
| `lambda_return` | `true` | Show return type hints for lambdas |
| `lambda_receivers_parameters` | `true` | Show receiver and parameter hints for lambdas |
| `value_ranges` | `true` | Show hints for value ranges |
| `kotlin_time` | `true` | Show kotlin.time package warnings |
| `call_chains` | `false` | Show intermediate result types in method-call chains |

#### Commands

- `:KotlinInlayHintsToggle` - Toggle inlay hints for the current buffer
- `:lua vim.lsp.inlay_hint.enable(true)` - Enable inlay hints
- `:lua vim.lsp.inlay_hint.enable(false)` - Disable inlay hints

#### Key Mapping Example

```lua
vim.keymap.set('n', '<leader>ih', function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = 'Toggle inlay hints' })
```

**Note:** The `KotlinHintsToggle` command toggles diagnostic hints (HINT severity diagnostics), while `KotlinInlayHintsToggle` controls LSP inlay hints. These are two different features.

#### Implementation Note

Inlay hints work by implementing a `workspace/configuration` handler that responds to server requests for the `jetbrains.kotlin` configuration section — kotlin-lsp requests configuration dynamically on every inlay hint request rather than using only the initial settings. The server flattens the response into dot-paths and string-matches them against IntelliJ's declarative inlay hint optionIds (`hints.parameters`, `hints.type.property`, `hints.lambda.return`, `hints.value.ranges`, ...), and only renders hints whose optionId is answered with `true`. Note that the key names deliberately differ from the JetBrains VS Code extension's `package.json` for four options — the extension contributes bundle name keys (`hints.settings.types.property`, ...) that the server never matches.

### Code Folding

When enabled (the default on kotlin-lsp v262.4739.0+ and Neovim 0.11+), the plugin wires `foldmethod=expr` with `foldexpr=v:lua.vim.lsp.foldexpr()` and sets `foldlevel=99` so files open with all folds expanded. Fold ranges (Kotlin functions, classes, blocks, imports, multiline comments) are pulled from kotlin-lsp via the standard `textDocument/foldingRange` request. To opt out, set `folding = { enabled = false }` in your setup.

Folding uses standard Vim keymaps — kotlin.nvim does not bind its own:

| Keymap | Action |
|--------|--------|
| `zo`   | Open fold under cursor |
| `zc`   | Close fold under cursor |
| `za`   | Toggle fold under cursor |
| `zR`   | Open all folds in the buffer |
| `zM`   | Close all folds in the buffer |
| `zj` / `zk` | Jump to next / previous fold |

See `:help fold-commands` for the full list.

### Available Commands

kotlin.nvim provides several commands for working with Kotlin code:

| Command | Description |
|---------|-------------|
| `:KotlinOrganizeImports` | Organize and optimize imports in the current file |
| `:KotlinFormat` | Format the current buffer using IntelliJ IDEA formatting rules |
| `:KotlinSymbols` | Show document symbols/outline for the current buffer (displays in trouble.nvim window) |
| `:KotlinWorkspaceSymbols` | Search for symbols across the entire workspace (displays in trouble.nvim window) |
| `:KotlinTypeDefinition` | Go to the type definition of the symbol under cursor (v262+) |
| `:KotlinImplementation` | Go to the implementation of the symbol under cursor (v262+) |
| `:KotlinIncomingCalls` | Show callers of the symbol under cursor (v262.4739.0+) |
| `:KotlinOutgoingCalls` | Show what the symbol under cursor calls (v262.4739.0+) |
| `:KotlinReferences` | Find all references to the symbol under cursor |
| `:KotlinRename` | Rename the symbol under cursor across the project |
| `:KotlinCodeActions` | Show all available code actions from kotlin-lsp |
| `:KotlinQuickFix` | Show quick fixes for diagnostics on current line |
| `:KotlinInlayHintsToggle` | Toggle inlay hints on/off for the current buffer |
| `:KotlinHintsToggle` | Toggle HINT severity diagnostics (if sent by the server) |
| `:KotlinNewFromTemplate` | Pick an IntelliJ-style file template and apply it to the current buffer (v262.4739.0+) |
| `:KotlinSupertypes` / `:KotlinSubtypes` | Type hierarchy of the symbol under cursor (v263.4702.0+) |
| `:KotlinExportWorkspaceToJson` | Export workspace structure to `workspace.json` |
| `:KotlinReloadWorkspace` | Re-import the project (resends the initialization options) without restarting the server (v263.4702.0+) |
| `:KotlinRestart` | Restart the Kotlin language server for all Kotlin buffers |
| `:KotlinCleanWorkspace` | Stop the server, delete this project's `--system-path` directory and the index directory the server reported, and restart |
| `:KotlinBuildLog` | Open the build-tool import / build output buffer |
| `:KotlinShowLogs` | Open the kotlin-lsp server log (for the current project) and Neovim's LSP log |
| `:KotlinRunMain [args]` | Run the `main` function in the current buffer (through Gradle when possible; requires nvim-dap, v263.4702.0+) |
| `:KotlinDebugMain [args]` | Debug the `main` function in the current buffer (requires nvim-dap, v263.4702.0+) |
| `:KotlinDebug [port]` | Attach debugger to a Kotlin/JVM process (JDWP port, default 5005; requires nvim-dap) |

> [!note]
> `:KotlinSymbols` and `:KotlinWorkspaceSymbols` require [trouble.nvim](https://github.com/folke/trouble.nvim) to display results in a clean, interactive window. These commands provide a better alternative to traditional location lists for browsing code structure.

**Key Mappings Example:**
```lua
-- Code actions and quick fixes
vim.keymap.set('n', '<leader>ka', ':KotlinCodeActions<CR>', { desc = 'Kotlin code actions' })
vim.keymap.set('n', '<leader>kq', ':KotlinQuickFix<CR>', { desc = 'Kotlin quick fix' })

-- Go to type definition
vim.keymap.set('n', '<leader>kt', ':KotlinTypeDefinition<CR>', { desc = 'Go to type definition' })

-- Go to implementation
vim.keymap.set('n', '<leader>ki', ':KotlinImplementation<CR>', { desc = 'Go to implementation' })

-- Organize imports
vim.keymap.set('n', '<leader>ko', ':KotlinOrganizeImports<CR>', { desc = 'Organize Kotlin imports' })

-- Format buffer
vim.keymap.set('n', '<leader>kf', ':KotlinFormat<CR>', { desc = 'Format Kotlin buffer' })

-- Show symbols
vim.keymap.set('n', '<leader>ks', ':KotlinSymbols<CR>', { desc = 'Show document symbols' })

-- Find references
vim.keymap.set('n', '<leader>kr', ':KotlinReferences<CR>', { desc = 'Find references' })

-- Rename symbol
vim.keymap.set('n', '<leader>kn', ':KotlinRename<CR>', { desc = 'Rename symbol' })

-- Toggle inlay hints
vim.keymap.set('n', '<leader>kh', ':KotlinInlayHintsToggle<CR>', { desc = 'Toggle inlay hints' })

-- Show LSP logs
vim.keymap.set('n', '<leader>kl', ':KotlinShowLogs<CR>', { desc = 'Show Kotlin LSP logs' })

-- Debug
vim.keymap.set('n', '<leader>kd', ':KotlinDebug<CR>', { desc = 'Debug Kotlin program' })
```

### Debugging Support

kotlin.nvim integrates with [nvim-dap](https://github.com/mfussenegger/nvim-dap) and kotlin-lsp's built-in debug adapter. When a session starts, the plugin sends `start_debug_server` to kotlin-lsp, which spins up a DAP server, and nvim-dap connects to it. The adapter is registered as `kotlin` (only if you have not configured one yourself).

#### Run or debug a `main` function (kotlin-lsp v263.4702.0+)

Every `main` function gets two code lenses, **Run** and **Debug** (rendered by `vim.lsp.codelens`; trigger the one under the cursor with `vim.lsp.codelens.run()`). The same launches are available as commands:

```vim
:KotlinRunMain                " run main() of the current file
:KotlinRunMain sync --force   " with program arguments
:KotlinDebugMain              " debug it (breakpoints, stepping, variables via nvim-dap)
```

How the program runs is resolved by the server, exactly like the VS Code extension does it:

- **Gradle module**: launched through Gradle (`intellij.java.resolveBuildToolLaunch`). Gradle compiles and runs; nothing is built separately.
- **Anything else** (Maven, plain JPS): the server returns the runtime paths (`intellij.java.resolveLaunch`: `java` executable, classpath, module path, working directory) and a build command (`intellij.java.resolveBuildCommand`). kotlin.nvim runs the build first, streaming its output to `:KotlinBuildLog`, and starts the program only if it succeeds. Set `dap.build_before_run = false` to skip the build.

Program output goes to a terminal split by default (`dap.console = "integratedTerminal"`, via DAP `runInTerminal`). Use `"internalConsole"` to stream it into the nvim-dap REPL instead.

The resolution runs in the adapter's `enrich_config` hook, so it applies to **every** launch configuration of the `kotlin` type, not only to the lenses: `dap.continue()` offers "Launch main class", "Launch main class (plain JVM)" and "Attach to JVM" out of the box (disable with `dap.configurations = false`), you can add your own to `dap.configurations.kotlin`, and a `.vscode/launch.json` written for the VS Code extension works unchanged. Its `intellij_jvm`, `intellij_gradle` and `intellij_debugger` types are routed to the same adapter, and `file`, `classPaths`, `modulePaths`, `moduleName`, `javaExec`, `projectPath`, `sourceSet` and `gradleArgs` are honored the way the extension honors them. Only `mainClass` is required.

```lua
-- dap.configurations.kotlin entry
{
  type = "kotlin", request = "launch", name = "Run server",
  mainClass = "com.example.ServerKt",
  launcher = "gradle",              -- "auto" | "gradle" | "jvm" (default "jvm" here, "auto" for the lens)
  args = { "--port", "8080" }, vmArgs = { "-Xmx1g" }, env = { APP_ENV = "dev" },
  build = true,                     -- plain JVM launches: compile first (default dap.build_before_run)
}
```

Programmatic use, including forcing a plain JVM launch for a Gradle module:

```lua
require("kotlin.dap").run_main({
  mainClass = "com.example.MainKt",
  noDebug = true,           -- false = debug
  launcher = "jvm",         -- "gradle" | "jvm" | nil (server decides)
  args = { "--verbose" },
  vmArgs = { "-Xmx1g" },
  env = { APP_ENV = "dev" },
})
```

#### Attach to a running JVM

1. Start your application with JDWP debugging enabled:
```sh
# Gradle
./gradlew run --debug-jvm

# Maven (tests)
mvn test -Dmaven.surefire.debug
```
Both default to JDWP port **5005**.

2. Open a Kotlin file to activate kotlin-lsp

3. Set breakpoints and attach the debugger:
```vim
:KotlinDebug          " prompts for port (default 5005)
:KotlinDebug 5005     " attach to port 5005 directly
:KotlinDebug 8000     " attach to a custom port
```

For breakpoint, stepping, REPL, and variable inspection workflows, see `:help dap.txt`. These are standard nvim-dap features and are not Kotlin-specific.

> [!note]
> nvim-dap is an optional dependency. If it is not installed, DAP features are silently skipped and the rest of the plugin works normally.

### Workspace reload, restart and build log

- `:KotlinReloadWorkspace` asks the server to re-import the project (`intellij/reloadWorkspace`, v263.4702.0+), resending the initialization options. The process and its indexes stay. With `reload_workspace.on_build_file_save` the plugin offers (`"ask"`, default) or performs (`"always"`) this whenever you save `build.gradle(.kts)`, `settings.gradle(.kts)` or `pom.xml`.
- `:KotlinRestart` stops and starts the server for all Kotlin buffers.
- `:KotlinBuildLog` shows the output of Gradle/Maven imports and of builds run before a launch. Import start, failure and success are also reported as notifications, and so is a folder whose import is blocked because it holds more than one build system (set `build_tool` and reload).

### Library sources, Java files and semantic highlighting

- **Library and JDK sources.** Go-to-definition into a dependency returns `jar:` or `jrt:` locations. kotlin.nvim fills the buffer through the server's `decompile` command (attached sources when the build tool downloaded them, decompiled bytecode otherwise), marks it read-only, and attaches the kotlin_lsp client to it, as the VS Code client's document selector does. Hover, further navigation and semantic highlighting therefore work inside `kotlin-stdlib-…-sources.jar!/…/Collections.kt` as well. Buffers open before a server restart are re-attached.
- **Java files.** The "Kotlin by JetBrains" bundle ships only the `java-base.lsp` plugin, which lets Kotlin analysis read Java code and lets Kotlin navigate into Java. It provides no features *inside* Java documents: definition, references, symbols, semantic tokens and completion all return empty (only hover answers, in library sources). Java features come from the `java.lsp` plugin of the "Java and Kotlin by IntelliJ IDEA" server. kotlin.nvim attaches to Java buffers anyway, as the VS Code client does, so unsaved Java edits reach Kotlin analysis immediately, but only to a server that a Kotlin file already started for the same project root: opening a Java file alone never starts kotlin-lsp. `java_files = false` turns this off. If you run jdtls alongside, filter formatting by client name (`vim.lsp.buf.format({ name = "jdtls" })`), since both clients advertise it.
- **Semantic tokens.** The server reports indexing through `$/progress` but never asks for a semantic-token refresh afterwards, so buffers opened during indexing kept degraded highlighting until an edit. kotlin.nvim refreshes them when the "Indexing" progress ends.
- **Live templates.** Completion items for `main`, `sout`, `fori` and friends use the same `jetbrains.kotlin.completion.apply` command as ordinary items, so the completion fix above covers them: accepting `sout` yields `println()` with the caret between the parentheses.

### IntelliJ intentions

kotlin-lsp v263.4702.0 exposes most Kotlin intentions from the IntelliJ plugin as code actions. Some of them need the editor: a "choose one of these" menu, copying text to the clipboard, or starting a rename after the edit. kotlin.nvim declares itself a JetBrains-aware client (`intellijExtensions`) and handles the resulting `intellij/chooseAction` (shown with `vim.ui.select`), `intellij/copyToClipboard` (`+` register) and `intellij/runEditorCommand` (`editor.action.rename` → `vim.lsp.buf.rename`, `editor.action.triggerSuggest` → completion, `editor.action.triggerParameterHints` → signature help) notifications, so these actions appear in `:KotlinCodeActions` / `vim.lsp.buf.code_action()` and work.

Hover text from the server may contain "Go to Super Method"-style links that only VS Code can follow; kotlin.nvim strips the link and keeps the label.

### Build expiry

kotlin-lsp builds embed a time-limited licence (for v263.4702.0 it runs out on 2026-10-08). When it lapses the launcher exits with code 7 and the server never starts. kotlin.nvim reports this with a clear message, and `:checkhealth kotlin` shows the licence status and date, so update kotlin-lsp before that (`:MasonInstall kotlin-lsp` or a newer GitHub release).

### Per-project state and indices

Each project gets its own `--system-path` directory, `~/.cache/kotlin-lsp-workspaces/<name>-<hash>` (`%LOCALAPPDATA%\kotlin-lsp-workspaces\<name>-<hash>` on Windows), keyed by the resolved project root so two projects with the same directory name do not collide. With kotlin-lsp v263.4702.0+ the server keeps its index inside that directory and reports the exact location (`capabilities.experimental.indexDir`); `:KotlinCleanWorkspace` deletes that directory and the reported index directory, and nothing else. Older plugin versions wiped the whole JetBrains analyzer cache, which also held the indexes of every other project.

> [!note]
> Upgrading from a version that named the directory `<name>` only: the old directories under `~/.cache/kotlin-lsp-workspaces/` are no longer used and can be deleted. The first start re-indexes.

## 📥 Language Server Installation

The plugin supports two installation methods for [kotlin-lsp][3]:

### Option 1: Mason Installation (Recommended)

You can easily install kotlin-lsp using [Mason][6] with the following command:

```vim
:MasonInstall kotlin-lsp
```

This is the recommended approach as Mason handles the installation automatically and includes platform-specific builds with a bundled JRE (zero-dependency installation). **No separate JDK installation is required** when using the Mason-installed kotlin-lsp.

The plugin launches kotlin-lsp through its `bin/intellij-server` native launcher (introduced in **v262.4739.0**), which manages its own bundled JBR. Older builds that only ship the `kotlin-lsp.sh` / `kotlin-lsp.cmd` shim are no longer supported — update your install if the launcher is missing.

### Option 2: Manual Installation

If you prefer not to use Mason or need to use a specific version of kotlin-lsp, you can install it manually and set the `KOTLIN_LSP_DIR` environment variable to point to your installation directory:

```bash
export KOTLIN_LSP_DIR=/path/to/your/kotlin-lsp
```

The plugin will automatically detect and use your manual installation when the environment variable is set. The install must contain the `bin/intellij-server` launcher (kotlin-lsp v262.4739.0+):

```
$KOTLIN_LSP_DIR/
├── bin/
│   └── intellij-server    (Unix/macOS launcher; .exe on Windows)
└── lib/
    └── ... (jar files)
```

> [!important]
> Download the official kotlin-lsp distribution from [GitHub releases](https://github.com/Kotlin/kotlin-lsp/releases) to make sure the `bin/intellij-server` launcher is bundled. Older builds that only ship the `kotlin-lsp.sh` / `kotlin-lsp.cmd` shim are no longer supported.

### Extra JVM Arguments

`bin/intellij-server` manages its own bundled JBR, so there is no JRE to configure. To pass extra JVM arguments (e.g., `-Xmx4g`) to the server, use the `jvm_args` option — they are forwarded via the `IJ_JAVA_OPTIONS` environment variable, which the kotlin-lsp server reads at startup.

```lua
require("kotlin").setup {
    jvm_args = { "-Xmx4g" },
}
```

> [!caution]
> If you use other tools like [nvim-lspconfig][8] or [mason-lspconfig][7], make sure to explicitly exclude the `kotlin_lsp` configuration there to avoid conflicts.

## 💐 Credits
- [nvim-jdtls][4]
- [kotlin-vscode][5]
- [rustaceanvim][10]
- [oil.nvim][11]
- [trouble.nvim][12]
- [nvim-dap][13]

[1]: https://microsoft.github.io/language-server-protocol/
[2]: https://neovim.io/
[3]: https://github.com/Kotlin/kotlin-lsp/
[4]: https://github.com/mfussenegger/nvim-jdtls
[5]: https://github.com/Kotlin/kotlin-lsp/tree/main/kotlin-vscode
[6]: https://github.com/mason-org/mason.nvim
[7]: https://github.com/mason-org/mason-lspconfig.nvim
[8]: https://github.com/neovim/nvim-lspconfig
[9]: https://github.com/Kotlin/kotlin-lsp/blob/main/scripts/neovim.md
[10]: https://github.com/mrcjkb/rustaceanvim
[11]: https://github.com/stevearc/oil.nvim
[12]: https://github.com/folke/trouble.nvim
[13]: https://github.com/mfussenegger/nvim-dap

<!-- MARKDOWN LINKS & IMAGES -->
[neovim-shield]: https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white
[neovim-url]: https://neovim.io/
[lua-shield]: https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white
[lua-url]: https://www.lua.org/
[kotlin-shield]: https://img.shields.io/badge/Kotlin-7F52FF?style=for-the-badge&logo=Kotlin&logoColor=white
[kotlin-url]: https://kotlinlang.org/
[issues-shield]: https://img.shields.io/github/issues/alexandrosalexiou/kotlin.nvim.svg?style=for-the-badge
[issues-url]: https://github.com/AlexandrosAlexiou/kotlin.nvim/issues
[license-shield]: https://img.shields.io/github/license/AlexandrosAlexiou/kotlin.nvim.svg?style=for-the-badge
[license-url]:https://github.com/AlexandrosAlexiou/kotlin.nvim/blob/main/LICENSE.txt
