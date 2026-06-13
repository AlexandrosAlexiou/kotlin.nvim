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

- [x] Decompile and open class file contents using kotlin-lsp `decompile` command
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
- [x] Automatic per-project workspace isolation to prevent LSP conflicts and improve performance
  - Use `KotlinCleanWorkspace` command to clear cached indices for the current project
- [x] Per-project LSP configuration via `.kotlin-lsp.lua` file
- [x] Per-project LSP disabling via marker file
  - Create a `.disable-kotlin-lsp` file in the project root to prevent the Kotlin LSP from starting (detected automatically by searching upward from the opened file)
- [x] DAP debugging support via nvim-dap (uses kotlin-lsp's built-in debug adapter)

> [!warning]
> DAP support is not yet finalized in the plugin. There is a known issue with the kotlin-lsp debug adapter. See [Kotlin/kotlin-lsp#198](https://github.com/Kotlin/kotlin-lsp/issues/198) for details.

> [!note]
> **Version Requirements:**
> - The plugin prefers the new `bin/intellij-server` launcher (kotlin-lsp **v262.4739.0+**) and falls back to the legacy `kotlin-lsp.sh` / `kotlin-lsp.cmd` script for older builds.
> - Workspace isolation with the `--system-path` parameter requires kotlin-lsp **v0.253.10629** or later.
> - Zero-dependencies platform-specific builds are supported -- no JDK required by default as the language server bundles its own (kotlin-lsp **v261+** or later).
> - Inlay hints require kotlin-lsp **v261+** and are configured using the exact format from the VSCode extension.
> - Code formatting and organize imports require kotlin-lsp **v0.253+** with IntelliJ IDEA-based formatting support.
> - "Go to Type Definition" and "Go to Implementation" require kotlin-lsp **v262+**.
> - Maven project import is supported starting from kotlin-lsp **v262+**.
> - Call hierarchy, LSP folding, file templates and the `build_tool` option require kotlin-lsp **v262.4739.0+**.
> - kotlin-lsp **v262.4739.0+** requires JDK 25 to run the server (the bundled JRE meets this; if you set `jre_path` make sure it points to a JDK 25 install).

## 📦 Installation

Install the plugin with your package manager:

**Dependencies:**
- [mason.nvim](https://github.com/williamboman/mason.nvim) - LSP installer
- [mason-lspconfig.nvim](https://github.com/williamboman/mason-lspconfig.nvim) - Mason LSP integration
- [oil.nvim](https://github.com/stevearc/oil.nvim) - File explorer for package navigation (used by "Go to Definition" on package declarations)
- [trouble.nvim](https://github.com/folke/trouble.nvim) - Enhanced quickfix/location list UI (required for `:KotlinSymbols` and `:KotlinWorkspaceSymbols` commands to display document outline and workspace symbols)

**Optional (install and configure separately):**
- Debug Adapter Protocol client ([nvim-dap](https://github.com/mfussenegger/nvim-dap)). Required for `:KotlinDebug`. kotlin.nvim does not install or configure nvim-dap for you — set it up once globally (signs, keymaps, optional UI) and kotlin.nvim will register a `kotlin` adapter on top.

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

            -- Optional: Java Runtime to run the kotlin-lsp server itself
            -- LEGACY ONLY — ignored on v262.4739.0+ (bin/intellij-server manages
            -- its own JBR; a warning is shown if this is set on a new install).
            -- Only useful with older builds that ship kotlin-lsp.sh / kotlin-lsp.cmd.
            --
            -- When set, the plugin parses JVM args from the bundled launcher script
            -- and invokes your custom JRE with the correct flags
            -- Must point to JAVA_HOME (directory containing bin/java)
            -- Examples:
            --   macOS:   "/Library/Java/JavaVirtualMachines/jdk-25.jdk/Contents/Home"
            --   Linux:   "/usr/lib/jvm/java-25-openjdk"
            --   Windows: "C:\\Program Files\\Java\\jdk-25"
            --   Env var: os.getenv("JAVA_HOME") or os.getenv("JDK25")
            jre_path = nil,

            -- Optional: JDK for symbol resolution (analyzing your Kotlin code)
            -- This is the JDK that your project code will be analyzed against
            -- Different from jre_path (which runs the server)
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
                types_property = true,  -- Show property types
                types_variable = true,  -- Show local variable types
                function_return = true,  -- Show function return types
                function_parameter = true,  -- Show function parameter types
                lambda_return = true,  -- Show lambda return types
                lambda_receivers_parameters = true,  -- Show lambda receivers/parameters
                value_ranges = true,  -- Show value ranges
                kotlin_time = true,  -- Show kotlin.time warnings
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

### Understanding JRE and JDK Options

kotlin.nvim provides two separate Java-related configuration options that serve different purposes:

#### 1. `jre_path` - Java Runtime for the LSP Server

**Purpose:** Specifies which Java runtime should be used to **run the kotlin-lsp server process itself**.

**When to use:**
- You want to run kotlin-lsp with a specific Java version
- You have specific JVM compatibility requirements for the server

When `jre_path` is set, the plugin parses JVM arguments from the bundled launcher
script and invokes your custom JRE with the correct flags. When not set, the
bundled launcher script handles everything automatically.

**Examples:**
```lua
-- macOS
jre_path = "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home"

-- Linux
jre_path = "/usr/lib/jvm/java-21-openjdk"

-- Windows
jre_path = "C:\\Program Files\\Java\\jdk-21"

-- Environment variable
jre_path = os.getenv("JAVA_HOME")

-- SDKMAN installation
jre_path = os.getenv("HOME") .. "/.sdkman/candidates/java/21.0.1-tem"
```

**Recommendation:** Leave as `nil` to use the bundled launcher and JRE (simplest setup).

#### 2. `jdk_for_symbol_resolution` - JDK for Code Analysis

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

#### Quick Reference

| Option | Purpose | Default | Typical Use Case |
|--------|---------|---------|------------------|
| `jre_path` | Run the LSP server | Bundled JRE (Mason) | Legacy only (pre-v262.4739.0) |
| `jdk_for_symbol_resolution` | Analyze your code | Auto-detect | Match project JDK version |

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

All settings default to `true` except `parameters_excluded`. Only specify settings you want to change:

```lua
require("kotlin").setup {
    inlay_hints = {
        enabled = true,  -- Master switch: enable/disable all inlay hints

        -- Parameter hints (show parameter names in function calls)
        parameters = true,  -- foo(name: "value", age: 42)
        parameters_compiled = true,  -- Show parameter names for compiled code
        parameters_excluded = false,  -- Show hints for excluded parameters (usually false)

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
| `types_property` | `true` | Show type hints for properties |
| `types_variable` | `true` | Show type hints for local variables |
| `function_return` | `true` | Show return type hints for functions |
| `function_parameter` | `true` | Show type hints for function parameters |
| `lambda_return` | `true` | Show return type hints for lambdas |
| `lambda_receivers_parameters` | `true` | Show receiver and parameter hints for lambdas |
| `value_ranges` | `true` | Show hints for value ranges |
| `kotlin_time` | `true` | Show kotlin.time package warnings |

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

Inlay hints work by implementing a `workspace/configuration` handler that responds to server requests for the `jetbrains.kotlin` configuration section. The handler builds a properly nested configuration object matching the VSCode extension format. This is crucial because kotlin-lsp requests configuration dynamically rather than using only the initial settings.

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
| `:KotlinExportWorkspaceToJson` | Export workspace structure to `workspace.json` |
| `:KotlinCleanWorkspace` | Clear cached indices and JetBrains analyzer cache for the current project |
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

-- Debug
vim.keymap.set('n', '<leader>kd', ':KotlinDebug<CR>', { desc = 'Debug Kotlin program' })
```

### Debugging Support

kotlin.nvim integrates with [nvim-dap](https://github.com/mfussenegger/nvim-dap) to provide debugging support through kotlin-lsp's built-in debug adapter. When you start a debug session, the plugin sends a `start_debug_server` command to kotlin-lsp, which spins up a DAP server, then attaches to your running JVM process via JDWP.

**Usage:**

1. Start your Kotlin application with JDWP debugging enabled:
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

The plugin registers a `kotlin` DAP adapter automatically. It is only set if not already configured by the user, so you can fully customize it in your nvim-dap setup.

For breakpoint, stepping, REPL, and variable inspection workflows, see `:help dap.txt`. These are standard nvim-dap features and are not Kotlin-specific.

> [!note]
> nvim-dap is an optional dependency. If it is not installed, DAP features are silently skipped and the rest of the plugin works normally.

### Shared Indices

Indices are now stored in a dedicated folder and properly shared between multiple projects and language server instances, improving performance and reducing disk usage.

## 📥 Language Server Installation

The plugin supports two installation methods for [kotlin-lsp][3]:

### Option 1: Mason Installation (Recommended)

You can easily install kotlin-lsp using [Mason][6] with the following command:

```vim
:MasonInstall kotlin-lsp
```

This is the recommended approach as Mason handles the installation automatically and includes platform-specific builds with a bundled JRE (zero-dependency installation). **No separate JDK installation is required** when using the Mason-installed kotlin-lsp.

The plugin auto-detects the launcher in the following order:

1. `bin/intellij-server` — the new native launcher introduced in **v262.4739.0** (preferred).
2. `kotlin-lsp.sh` / `kotlin-lsp.cmd` — the deprecated shim used by older builds. Still works, but JetBrains will remove it in a future release.
3. A manual `java -cp lib/* …KotlinLspServerKt --stdio` fallback for installs that contain only `lib/`.

### Option 2: Manual Installation

If you prefer not to use Mason or need to use a specific version of kotlin-lsp, you can install it manually and set the `KOTLIN_LSP_DIR` environment variable to point to your installation directory:

```bash
export KOTLIN_LSP_DIR=/path/to/your/kotlin-lsp
```

The plugin will automatically detect and use your manual installation when the environment variable is set. Either layout below is supported:

```
# v262.4739.0+ (preferred)
$KOTLIN_LSP_DIR/
├── bin/
│   └── intellij-server    (Unix/macOS launcher; .exe on Windows)
├── kotlin-lsp.sh          (deprecated shim, optional)
├── kotlin-lsp.cmd         (deprecated shim, optional)
└── lib/
    └── ... (jar files)

# Pre-v262.4739.0
$KOTLIN_LSP_DIR/
├── kotlin-lsp.sh
├── kotlin-lsp.cmd
└── lib/
    └── ... (jar files)
```

> [!important]
> Download the official kotlin-lsp distribution from [GitHub releases](https://github.com/Kotlin/kotlin-lsp/releases) to make sure a launcher is bundled. The plugin can fall back to a manual `java -cp lib/* …` invocation if no launcher is present, but you'll need a JDK 25 install on `PATH` or via `jre_path` for that path.

### Custom JRE

> [!warning]
> **v262.4739.0+:** The new `bin/intellij-server` launcher manages its own bundled JBR. `jre_path` is **ignored** on these versions and a warning is shown if set. This option is only useful with older builds that ship `kotlin-lsp.sh` / `kotlin-lsp.cmd`.

If you need to run an **older** kotlin-lsp with a specific Java runtime (e.g., for compatibility or performance), use the `jre_path` configuration option. The plugin parses the JVM arguments from the legacy `kotlin-lsp.sh` launcher and invokes your custom JRE directly with the correct flags.

```lua
jre_path = "/path/to/jdk-25"  -- Must point to JAVA_HOME (directory containing bin/java); JDK 25+ required for v262.4739.0+
```

Additional JVM arguments (e.g., `-Xmx4g`) are passed via the `IJ_JAVA_OPTIONS` environment variable, which is read by the kotlin-lsp server at startup.

> [!caution]
> If you use other tools like [nvim-lspconfig][8] or [mason-lspconfig][7], make sure to explicitly exclude the `kotlin_lsp` configuration there to avoid conflicts.

## 💐 Credits
- [nvim-jdtls][4]
- [kotlin-vscode][5]
- [rustaceanvim][10]
- [oil.nvim][11]
- [trouble.nvim][12]
- [nvim-dap][13]

## Star History

<a href="https://www.star-history.com/?repos=alexandrosalexiou%2Fkotlin.nvim&type=date&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=alexandrosalexiou/kotlin.nvim&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=alexandrosalexiou/kotlin.nvim&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=alexandrosalexiou/kotlin.nvim&type=date&legend=top-left" />
 </picture>
</a>

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
