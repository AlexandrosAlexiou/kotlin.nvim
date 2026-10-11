Configuration
=============

Every option is optional. `require("kotlin").setup({})` (or `opts = {}` in
lazy.nvim) starts kotlin-lsp with the defaults below.

- [All options](#all-options)
- [Per-project configuration](#per-project-configuration)
- [Disabling the server for a project](#disabling-the-server-for-a-project)
- [JDK for symbol resolution](#jdk-for-symbol-resolution)
- [Server JVM arguments](#server-jvm-arguments)
- [Inlay hints](#inlay-hints)
- [Folding](#folding)
- [Projects and build tools](#projects-and-build-tools)

<br>

## All options

```lua
require("kotlin").setup {
    -- Files that mark the project root. Default:
    -- { "build.gradle", "build.gradle.kts", "pom.xml", "mvnw" }
    root_markers = { "gradlew", ".git", "mvnw", "settings.gradle" },

    -- JDK your code is analyzed against (not the one the server runs on).
    -- nil = detect from the project.
    jdk_for_symbol_resolution = nil,

    -- Extra JVM arguments for the server.
    jvm_args = { "-Xmx4g" },

    -- See "Inlay hints" below for every hint toggle.
    inlay_hints = { enabled = true },

    -- LSP-driven folding (foldexpr). Default true.
    folding = { enabled = true },

    -- Build-tool importer: nil = server decides, "gradle", "maven",
    -- or "" for no build system.
    build_tool = nil,

    -- Projects to import explicitly (see "Projects and build tools").
    projects = nil,

    -- Re-import when build.gradle(.kts), settings.gradle(.kts) or pom.xml is
    -- saved: "ask" (default), "always" or "never".
    reload_workspace = { on_build_file_save = "ask" },

    -- Run/Debug code lenses above `main` functions.
    code_lens = {
        enabled = true,
        -- The server titles lenses with VS Code codicons; these replace them
        -- (Nerd Font glyphs by default). `icons = false` shows text only.
        -- icons = { play = "", debug = "" },
        align = true, -- draw the lens at the line's indent instead of at `main`
    },

    -- Launching programs (requires nvim-dap, see debugging.md).
    dap = {
        console = "integratedTerminal", -- or "internalConsole" (dap REPL)
        build_before_run = true,        -- plain JVM launches compile first
        configurations = true,          -- default dap.configurations entries
        inline_stack_frames = false,    -- see debugging.md
    },

    -- Also attach to Java buffers of a project whose server is already
    -- running, like the VS Code client (see features.md).
    java_files = true,

    -- JetBrains data sharing / region, as asked by the VS Code extension on
    -- first start. Unset = share nothing.
    -- data_sharing: "none" | "anonymous" | "full"
    -- region: "africa" | "americas" | "apac" | "china" | "europe"
    --         | "middle_east" | "oceania"
    data_sharing = nil,
    region = nil,

    -- Disable the RocksDB write-ahead log of the index
    -- (VS Code `intellij.disableRocksDBWriteAheadLog`).
    disable_rocksdb_wal = false,

    -- Templates offered when you create a new .kt file. A table of
    -- name -> Velocity template overrides the defaults (Class, File,
    -- Interface, Data Class, Enum, Annotation, Object).
    -- { enabled = false } turns the prompt off.
    file_templates = {
        enabled = true,
        -- Class = "package ${PACKAGE_NAME}\n\nclass ${NAME} {\n\t|\n}",
    },
}
```

The same reference is available inside Neovim as `:help kotlin.setup`.

<br>

## Per-project configuration

A `.kotlin-lsp.lua` file in the project root (found by searching upward from
the opened file) returns options that override the global ones for that
project:

```lua
-- .kotlin-lsp.lua
return {
    jdk_for_symbol_resolution = "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home",
    inlay_hints = { enabled = false },
    jvm_args = { "-Xmx8g" },
}
```

The two tables are deep-merged and the project file wins. After editing it,
run `:KotlinRestart`. Options that only affect the import (`build_tool`,
`projects`, `jdk_for_symbol_resolution`) are also picked up by
`:KotlinReloadWorkspace`, which keeps the server and its indexes.

A typical use is a workspace whose projects target different JDKs:

```
~/projects/
  ├── legacy-app/              # JDK 11
  │   └── .kotlin-lsp.lua      # jdk_for_symbol_resolution = "/path/to/jdk-11"
  └── modern-app/              # JDK 21
      └── .kotlin-lsp.lua      # jdk_for_symbol_resolution = "/path/to/jdk-21"
```

Commit the file if the whole team should share the settings, or add it to
`.gitignore` if they are personal.

<br>

## Disabling the server for a project

kotlin-lsp does not handle every project layout yet. To keep it from starting
in one project, create an empty marker file in the project root:

```sh
touch .disable-kotlin-lsp
```

The plugin searches upward from the opened file, so the marker works whatever
your current directory is. Creating it while the server runs stops the client
on the next Kotlin buffer you open.

For a single buffer, set `vim.b.disable_kotlin_lsp = true` before the client
attaches.

<br>

## JDK for symbol resolution

The server runs on its own bundled runtime. `jdk_for_symbol_resolution`
chooses the JDK whose standard library your **code** is analyzed against:
completion and navigation for JDK APIs, platform types, and so on. Set it to
your project's target JDK when the detected one is wrong, or per project in
`.kotlin-lsp.lua`.

```lua
jdk_for_symbol_resolution = "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home" -- macOS
jdk_for_symbol_resolution = "/usr/lib/jvm/java-21-openjdk"                             -- Linux
jdk_for_symbol_resolution = "C:\\Program Files\\Java\\jdk-17"                          -- Windows
jdk_for_symbol_resolution = os.getenv("HOME") .. "/.sdkman/candidates/java/17.0.8-tem" -- SDKMAN
```

<br>

## Server JVM arguments

`jvm_args` is passed to the server through the `IJ_JAVA_OPTIONS` environment
variable, appended to any value you already export. The usual reason is a
larger heap for big projects:

```lua
jvm_args = { "-Xmx8g" }
```

<br>

## Inlay hints

Hints render through Neovim's `vim.lsp.inlay_hint` and are enabled on attach
when `inlay_hints.enabled` is true. Each kind can be switched off. Only set the
ones you want to change.

```lua
inlay_hints = {
    enabled = true,                     -- master switch

    parameters = true,                  -- foo(name: "value", age: 42)
    parameters_compiled = true,         -- parameter names for compiled code
    parameters_excluded = false,        -- excluded parameters
    parameters_context = false,         -- context parameters

    types_property = true,              -- val name: String = "foo"
    types_variable = true,              -- val count: Int = 42
    function_return = true,             -- fun foo(): String
    function_parameter = true,          -- fun foo(name: String)

    lambda_return = true,               -- { x -> x * 2 }: (Int) -> Int
    lambda_receivers_parameters = true, -- lambda receivers and parameters

    value_ranges = true,                -- value ranges
    kotlin_time = true,                 -- kotlin.time warnings
    call_chains = false,                -- type after each step of a call chain
},
```

`:KotlinInlayHintsToggle` toggles them for the current buffer. To bind it:

```lua
vim.keymap.set("n", "<leader>ih", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })
```

`:KotlinHintsToggle` is a different feature: it hides or shows
HINT-severity *diagnostics*.

How it works: kotlin-lsp asks for the `jetbrains.kotlin` configuration section
on every inlay-hint request and renders only the hints whose IntelliJ option id
(`hints.parameters`, `hints.type.property`, `hints.lambda.return`, …) is
answered with `true`. kotlin.nvim implements that `workspace/configuration`
handler, which is why the client must be started by kotlin.nvim (see the
mason-lspconfig note in [installation.md](installation.md#dependencies)).
Four of the keys deliberately differ from the VS Code extension's
`package.json`, whose bundle-name keys the server never matches.

<br>

## Folding

With `folding.enabled` (the default), the plugin sets
`foldmethod=expr`, `foldexpr=v:lua.vim.lsp.foldexpr()` and `foldlevel=99`, so
files open fully expanded and fold ranges (functions, classes, blocks,
imports, multiline comments) come from the server. kotlin.nvim binds no keys;
use the usual `zo`, `zc`, `za`, `zR`, `zM`, `zj` / `zk` (`:help fold-commands`).

<br>

## Projects and build tools

By default the server imports the project at the root with whichever build
tool it finds. `build_tool` forces one:

```lua
build_tool = "gradle" -- or "maven", or "" for a project with no build system
```

If a folder contains more than one build system the server blocks its import
and kotlin.nvim tells you so. Set `build_tool` and run `:KotlinReloadWorkspace`.

`projects` lists the projects to import explicitly. It mirrors VS Code's
`intellij.projects` and is useful for monorepos or several independent projects
in one workspace. `path` is a build file or a directory, absolute or relative to
the root.

```lua
projects = {
    { type = "gradle", path = "backend" },
    {
        type = "maven",
        path = "tools/pom.xml",
        java_home = "/path/to/jdk-17",
        env = { MAVEN_OPTS = "-Xmx1g" },
        system_properties = { ["skip.tests"] = "true" },
        profiles = { "ci" },                    -- Maven profiles (v263.6379.0+)
        offline = true,                         -- only already-downloaded artifacts (v263.6379.0+)
        download_additional_artifacts = false,  -- skip sources/javadoc jars (v263.6379.0+)
    },
},
```

`type` is one of `gradle`, `maven`, `bazel`, `jps`, `json` or `subproject`;
`project_path` is the Bazel project file.

> [!note]
> The server clears the environment for Maven, so variables your build needs
> (`MAVEN_OPTS`, proxy settings, …) must be passed through `env`.

Saving a build file offers to re-import (`reload_workspace.on_build_file_save`).
Import output goes to `:KotlinBuildLog`.
