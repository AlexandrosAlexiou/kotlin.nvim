Running and debugging
=====================

kotlin-lsp has a built-in debug adapter. kotlin.nvim connects it to
[nvim-dap](https://github.com/mfussenegger/nvim-dap): when a session starts,
the plugin sends `start_debug_server` to the server, which starts a DAP server,
and nvim-dap connects to it. The adapter is registered as `kotlin` unless you
configured one with that name yourself.

nvim-dap is optional and set up by you (signs, keymaps, UI). Breakpoints,
stepping, the REPL and variable inspection are standard nvim-dap features, see
`:help dap.txt`.

- [Run or debug `main`](#run-or-debug-main)
- [How the launch is resolved](#how-the-launch-is-resolved)
- [Launch configurations and launch.json](#launch-configurations-and-launchjson)
- [Attach to a running JVM](#attach-to-a-running-jvm)
- [Inline functions](#inline-functions)

<br>

## Run or debug `main`

*Requires kotlin-lsp v263.4702.0+*

Every `main` function gets **Run** and **Debug** code lenses. Trigger the one
under the cursor with `vim.lsp.codelens.run()`. The same launches are
commands:

```vim
:KotlinRunMain                " run main() of the current file
:KotlinRunMain sync --force   " with program arguments
:KotlinDebugMain              " debug it
```

Program output goes to a terminal split (`dap.console = "integratedTerminal"`,
through DAP `runInTerminal`). `"internalConsole"` streams it into the nvim-dap
REPL instead.

<br>

## How the launch is resolved

The server decides, as it does for the VS Code extension:

- **Gradle module.** The program is launched through Gradle
  (`intellij.java.resolveBuildToolLaunch`), which compiles and runs it.
- **Anything else** (Maven, plain JPS). The server returns the `java`
  executable, classpath, module path and working directory
  (`intellij.java.resolveLaunch`) and a build command
  (`intellij.java.resolveBuildCommand`). kotlin.nvim runs the build first,
  streaming its output to `:KotlinBuildLog`, and starts the program only if the
  build succeeds. `dap.build_before_run = false` skips the build.

From v263.6379.0 the server also adds the VM arguments the project needs, such
as `--enable-preview` for a module compiled at a preview language level.

<br>

## Launch configurations and launch.json

The resolution runs in the adapter's `enrich_config` hook, so it applies to
**every** launch configuration of type `kotlin`, not only to the lenses.

- `dap.continue()` offers "Launch main class", "Launch main class (plain JVM)"
  and "Attach to JVM" out of the box. `dap.configurations = false` leaves
  `dap.configurations.kotlin` / `java` alone.
- Your own entries in `dap.configurations.kotlin` work. Only `mainClass` is
  required:

  ```lua
  {
      type = "kotlin", request = "launch", name = "Run server",
      mainClass = "com.example.ServerKt",
      launcher = "gradle",   -- "auto" | "gradle" | "jvm"
      args = { "--port", "8080" },
      vmArgs = { "-Xmx1g" },
      env = { APP_ENV = "dev" },
      build = true,          -- plain JVM launches: compile first
  }
  ```

- A `.vscode/launch.json` written for the VS Code extension works unchanged.
  Its `intellij_jvm`, `intellij_gradle` and `intellij_debugger` types go to the
  same adapter, and `file`, `classPaths`, `modulePaths`, `moduleName`,
  `javaExec`, `projectPath`, `sourceSet` and `gradleArgs` are honored the way
  the extension honors them.

From Lua, for example to force a plain JVM launch of a Gradle module:

```lua
require("kotlin.dap").run_main({
    mainClass = "com.example.MainKt",
    noDebug = true,     -- false = debug
    launcher = "jvm",   -- "gradle" | "jvm" | nil (server decides)
    args = { "--verbose" },
    vmArgs = { "-Xmx1g" },
    env = { APP_ENV = "dev" },
})
```

<br>

## Attach to a running JVM

Start the program with JDWP enabled. Both of these listen on port 5005:

```sh
./gradlew run --debug-jvm          # Gradle
mvn test -Dmaven.surefire.debug    # Maven tests
```

Open a Kotlin file of the project so the server runs, set breakpoints, and
attach:

```vim
:KotlinDebug          " prompts for the port (default 5005)
:KotlinDebug 8000     " attach to port 8000
```

<br>

## Inline functions

kotlin.nvim starts the server with
`-Ddebugger.kotlin.inline.stack.trace.enabled=false`. In kotlin-lsp
v263.4702.0, pausing in a synthetic Kotlin inline frame hit a
`NullPointerException` on the server and the pause was never reported, so
stepping into any `inline` function (`let`, `map`, Spring's `runApplication`, …)
left the JVM suspended while nvim-dap showed it running. With inline frames off,
step-into lands in the inlined body as part of the caller's frame.

Set `dap.inline_stack_frames = true` to get the synthetic frames back once the
server is fixed.
