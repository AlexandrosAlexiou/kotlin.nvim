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
- [x] Support for custom JVM arguments
- [x] Support kotlin-lsp installation from [Mason][6]
- [x] Navigate to package folders from package declarations (opens the folder view with [oil.nvim][11] using LSP "go to definition")
- [x] Automatic per-project workspace isolation to prevent LSP conflicts and improve performance

> [!note]
> Workspace isolation with the `--system-path` parameter requires kotlin-lsp **v0.253.10629** or later.

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
            jre_path = os.getenv("JDK21"),
            -- Optional: Specify additional JVM arguments
            jvm_args = {
                "-Xmx4g",
            },
        }
    end,
},

```

## 📥 Language Server Installation

You can easily install [kotlin-lsp][3] using [Mason][6] with the following command:

```vim
:MasonInstall kotlin-lsp
```

> [!caution]
> If you use other tools like [nvim-lspconfig][8] or [mason-lspconfig][7], make sure to explicitly exclude the `kotlin_lsp` configuration there to avoid conflicts.

There is no need to follow the manual installation steps from the [upstream guide][9]. Mason will handle everything for you.

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
