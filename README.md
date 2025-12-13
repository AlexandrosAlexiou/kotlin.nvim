<!-- markdownlint-disable -->
<br />
<div align="center">
  <a href="https://github.com/AlexandrosAlexiou/kotlin.nvim">
    <img src="./kotlin.nvim.svg" alt="rustaceanvim">
  </a>
  <p align="center">
    <br />
    <a href="./doc/kotlin.nvim.txt"><strong>Explore the docs »</strong></a>
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
- [x] Toggle hints using the `KotlinHintsToggle` command
- [x] JDK version specification for symbol resolution
- [x] Support for custom JVM arguments
- [x] Support kotlin-lsp installation from [Mason][6]
- [x] Navigate to package folders from package declarations (opens the folder view with [oil.nvim][11] using LSP "go to definition")
- [x] Automatic per-project workspace isolation to prevent LSP conflicts and improve performance
  - Use `KotlinCleanWorkspace` command to clear cached indices for the current project
- [x] Per-project LSP configuration via `.kotlin-lsp.lua` file
- [x] Per-project LSP disabling via marker file
  - Create a `.disable-kotlin-lsp` file in the project root to prevent the Kotlin LSP from being registered

> [!note]
> Workspace isolation with the `--system-path` parameter requires kotlin-lsp **v0.253.10629** or later.

> [!note]
> Zero-dependencies platform-specific builds are supported -- no JDK required by default as the language server bundles its own (kotlin-lsp v0.254+ or later).

## 📦 Installation

Install the plugin with your package manager:

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "AlexandrosAlexiou/kotlin.nvim",
    ft = { "kotlin" },
    dependencies = { "mason.nvim", "mason-lspconfig.nvim", "oil.nvim" },
    config = function()
        require("kotlin").setup {
            -- Optional: Specify root markers for multi-module projects
            root_markers = {
                "gradlew",
                ".git",
                "mvnw",
                "settings.gradle",
            },
            -- Optional: Specify a custom Java path to run the server
            -- Not required when using Mason installation (bundled JRE)
            jre_path = os.getenv("JDK21"),
            -- Optional: Specify additional JVM arguments
            jvm_args = {
                "-Xmx4g",
            },
            -- Optional: Specify JDK for symbol resolution (requires kotlin-lsp v0.254+)
            -- This specifies which JDK to use for resolving symbols and APIs
            -- Can be a path to JDK installation (e.g., "/path/to/jdk-21")
            -- or potentially a version string depending on kotlin-lsp implementation
            jdk_for_symbol_resolution = "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home",
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

When using the Mason-installed kotlin-lsp (v0.254+), no separate JDK installation is required. The language server includes platform-specific builds with a bundled JRE, providing a truly zero-dependency setup experience.

### JDK for Symbol Resolution

The `jdk_for_symbol_resolution` option allows you to specify which JDK should be used for symbol resolution and API lookups. This is useful when:

- Your project targets a specific Java/JDK version (e.g., Java 17, 21)
- You want code completion to show APIs from a specific JDK version
- You need to resolve symbols against a particular JDK's standard library

**Note:** This is different from `jre_path`:
- `jre_path`: JRE used to **run** the language server itself
- `jdk_for_symbol_resolution`: JDK used for **analyzing** your Kotlin code and resolving Java symbols

Example:
```lua
require("kotlin").setup {
    -- Run the LSP with bundled JRE (automatic from Mason)
    -- But analyze code against JDK 21 APIs
    jdk_for_symbol_resolution = "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home",
}
```

### Enhanced Code Completion

The latest kotlin-lsp versions offer significantly improved code completion:
- Suggestion ordering on par with IntelliJ IDEA
- ~30% better completion latency
- More relevant and context-aware suggestions

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

The plugin will automatically detect and use the bundled JRE from the Mason installation, providing a seamless zero-configuration experience.

### Option 2: Manual Installation

If you prefer not to use Mason or need to use a specific version of kotlin-lsp, you can install it manually and set the `KOTLIN_LSP_DIR` environment variable to point to your installation directory:

```bash
export KOTLIN_LSP_DIR=/path/to/your/kotlin-lsp
```

The plugin will automatically detect and use your manual installation when the environment variable is set. Ensure your installation has the following structure:

```
$KOTLIN_LSP_DIR/
└── lib/
    └── ... (jar files)
```

For manual installations, you'll need to provide a JRE either through:
- The `jre_path` configuration option
- The `JAVA_HOME` environment variable
- A system-wide `java` installation

> [!tip]
> The plugin automatically prioritizes JRE selection in this order:
> 1. User-specified `jre_path` in configuration
> 2. Bundled JRE from Mason kotlin-lsp installation (zero-dependency)
> 3. `JAVA_HOME` environment variable
> 4. System-wide `java` installation

> [!caution]
> If you use other tools like [nvim-lspconfig][8] or [mason-lspconfig][7], make sure to explicitly exclude the `kotlin_lsp` configuration there to avoid conflicts.

## 💐 Credits
- [nvim-jdtls][4]
- [kotlin-vscode][5]
- [rustaceanvim][10]
- [oil.nvim][11]

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
