# kotlin.nvim

Extensions for the built-in [Language Server Protocol][1] support in [Neovim][2] (>= 0.11.0) for [kotlin-lsp][3].

## 🧩 Extensions

- [x] Decompile and open class file contents using kotlin-lsp `decompile` command
- [x] Export workspace to JSON using kotlin-lsp `exportWorkspace` command
- [x] Support kotlin-lsp installation from [Mason][6]


## 📦 Installation

Install the plugin with your package manager:

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "AlexandrosAlexiou/kotlin.nvim",
    ft = { "kotlin" },
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
            jre_path = os.getenv("JDK21")
        }
    end,
},

```

## 🧱 Language Server Installation

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

[1]: https://microsoft.github.io/language-server-protocol/
[2]: https://neovim.io/
[3]: https://github.com/Kotlin/kotlin-lsp/
[4]: https://github.com/mfussenegger/nvim-jdtls
[5]: https://github.com/Kotlin/kotlin-lsp/tree/main/kotlin-vscode
[6]: https://github.com/mason-org/mason.nvim
[7]: https://github.com/mason-org/mason-lspconfig.nvim
[8]: https://github.com/neovim/nvim-lspconfig
[9]: https://github.com/Kotlin/kotlin-lsp/blob/main/scripts/neovim.md
