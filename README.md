<!-- markdownlint-disable -->
<br />
<div align="center">
  <a href="https://github.com/AlexandrosAlexiou/kotlin.nvim">
    <img src="./.github/kodee.svg" alt="kotlin.nvim" width="400">
  </a>
  <p align="center">
    <br />
    <a href="./doc/kotlin.nvim.txt"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/AlexandrosAlexiou/kotlin.nvim/issues/new?assignees=&labels=bug&projects=&template=bug_report.yml">Report Bug</a>
    ·
    <a href="https://github.com/AlexandrosAlexiou/kotlin.nvim/discussions/new?category=ideas">Request Feature</a>
    ·
    <a href="https://github.com/AlexandrosAlexiou/kotlin.nvim/discussions/new?category=q-a">Ask Question</a>
  </p>
  <p>
<strong>
Extensions for JetBrains' <a href="https://github.com/Kotlin/kotlin-lsp/">Kotlin Language Server (kotlin-lsp)</a> support in <a href="https://neovim.io/">Neovim</a><br /> (>=0.11.0).
</strong>
  </p>

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
- [x] Maven project import support (kotlin-lsp v262+)
- [x] Automatic per-project workspace isolation to prevent LSP conflicts and improve performance
  - Use `KotlinCleanWorkspace` command to clear cached indices for the current project
- [x] Per-project LSP configuration via `.kotlin-lsp.lua` file
- [x] Per-project LSP disabling via marker file
  - Create a `.disable-kotlin-lsp` file in the project root to prevent the Kotlin LSP from being registered
- [x] DAP debugging support via nvim-dap (uses kotlin-lsp's built-in debug adapter)

> [!note]
> **Version Requirements:**
> - The plugin uses the bundled launcher script (`kotlin-lsp.sh` / `kotlin-lsp.cmd`) from the kotlin-lsp distribution to handle JVM configuration automatically.
> - Workspace isolation with the `--system-path` parameter requires kotlin-lsp **v0.253.10629** or later.
> - Zero-dependencies platform-specific builds are supported -- no JDK required by default as the language server bundles its own (kotlin-lsp **v261+** or later).
> - Inlay hints require kotlin-lsp **v261+** and are configured using the exact format from the VSCode extension.
> - Code formatting and organize imports require kotlin-lsp **v0.253+** with IntelliJ IDEA-based formatting support.
> - "Go to Type Definition" and "Go to Implementation" require kotlin-lsp **v262+**.
> - Maven project import is supported starting from kotlin-lsp **v262+**.

## 📦 Installation

Install the plugin with your package manager:

**Dependencies:**
- [mason.nvim](https://github.com/williamboman/mason.nvim) - LSP installer
- [mason-lspconfig.nvim](https://github.com/williamboman/mason-lspconfig.nvim) - Mason LSP integration
- [oil.nvim](https://github.com/stevearc/oil.nvim) - File explorer for package navigation (used by "Go to Definition" on package declarations)
- [trouble.nvim](https://github.com/folke/trouble.nvim) - Enhanced quickfix/location list UI (required for `:KotlinSymbols` and `:KotlinWorkspaceSymbols` commands to display document outline and workspace symbols)

**Optional:**
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) - Debug Adapter Protocol client (required for `:KotlinDebug` command)

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
        -- Uncomment to enable :KotlinDebug command
        -- "mfussenegger/nvim-dap",
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
            -- NOT REQUIRED when using Mason (the bundled launcher handles JRE automatically)
            --
            -- When set, the plugin parses JVM args from the bundled launcher script
            -- and invokes your custom JRE with the correct flags
            -- Must point to JAVA_HOME (directory containing bin/java)
            -- Examples:
            --   macOS:   "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home"
            --   Linux:   "/usr/lib/jvm/java-21-openjdk"
            --   Windows: "C:\\Program Files\\Java\\jdk-21"
            --   Env var: os.getenv("JAVA_HOME") or os.getenv("JDK21")
            jre_path = nil,  -- Use bundled JRE (recommended)

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
| `jre_path` | Run the LSP server | Bundled JRE (Mason) | Override server runtime |
| `jdk_for_symbol_resolution` | Analyze your code | Auto-detect | Match project JDK version |

### Enhanced Code Completion

The latest kotlin-lsp versions offer significantly improved code completion:
- Suggestion ordering on par with IntelliJ IDEA
- ~30% better completion latency
- More relevant and context-aware suggestions

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
| `:KotlinReferences` | Find all references to the symbol under cursor |
| `:KotlinRename` | Rename the symbol under cursor across the project |
| `:KotlinCodeActions` | Show all available code actions from kotlin-lsp |
| `:KotlinQuickFix` | Show quick fixes for diagnostics on current line |
| `:KotlinInlayHintsToggle` | Toggle inlay hints on/off for the current buffer |
| `:KotlinHintsToggle` | Toggle HINT severity diagnostics (if sent by the server) |
| `:KotlinExportWorkspaceToJson` | Export workspace structure to `workspace.json` |
| `:KotlinCleanWorkspace` | Clear cached indices for the current project |
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

The plugin uses the bundled launcher script (`kotlin-lsp.sh` / `kotlin-lsp.cmd`) from the Mason installation, which handles JRE detection, JVM arguments, and classpath internally.

### Option 2: Manual Installation

If you prefer not to use Mason or need to use a specific version of kotlin-lsp, you can install it manually and set the `KOTLIN_LSP_DIR` environment variable to point to your installation directory:

```bash
export KOTLIN_LSP_DIR=/path/to/your/kotlin-lsp
```

The plugin will automatically detect and use your manual installation when the environment variable is set. The installation must include the bundled launcher script and lib directory:

```
$KOTLIN_LSP_DIR/
├── kotlin-lsp.sh       (Unix/macOS launcher)
├── kotlin-lsp.cmd      (Windows launcher)
└── lib/
    └── ... (jar files)
```

> [!important]
> The plugin relies on the bundled launcher script (`kotlin-lsp.sh` / `kotlin-lsp.cmd`) to configure JVM arguments and classpath. Download the official kotlin-lsp distribution from [GitHub releases](https://github.com/Kotlin/kotlin-lsp/releases) to ensure the launcher script is included.

### Custom JRE

If you need to run kotlin-lsp with a specific Java runtime (e.g., for compatibility or performance), use the `jre_path` configuration option. The plugin will parse JVM arguments from the bundled launcher script and invoke your custom JRE with the correct flags.

```lua
jre_path = "/path/to/jdk-21"  -- Must point to JAVA_HOME (directory containing bin/java)
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
