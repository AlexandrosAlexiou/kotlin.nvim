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
- [Run or debug tests](#run-or-debug-tests)
- [How a program is launched](#how-a-program-is-launched)
- [Launch configurations and launch.json](#launch-configurations-and-launchjson)
- [Attach to a running JVM](#attach-to-a-running-jvm)

<br>

## Run or debug `main`

Every `main` function gets **Run** and **Debug** code lenses. Trigger the one
under the cursor with `vim.lsp.codelens.run()`. The same launches are
commands:

```vim
:KotlinRunMain                " run main() of the current file
:KotlinRunMain sync --force   " with program arguments
:KotlinDebugMain              " debug it
```

The server runs the program and streams its output, build included, to the
nvim-dap REPL. kotlin.nvim opens the REPL when the first output arrives, unless
a window (nvim-dap-ui, for example) already shows it.
`dap.console = "internalConsole"` leaves opening it to you.

<br>

## Run or debug tests

JUnit and TestNG test classes and methods get **Run Test** and **Debug Test**
lenses, triggered with `vim.lsp.codelens.run()` like the ones above `main`.
The server builds the module and starts the test runner; results are printed in
the REPL, one line per test, with the message and stack trace of each failure:

```
✓ greetsByName() (18 ms)
✗ failsOnPurpose()
org.opentest4j.AssertionFailedError: expected: <nope> but was: <Hello, x>
	at demo.GreetTest.failsOnPurpose(GreetTest.kt:14)
```

<br>

## How a program is launched

The server does all of it, as it does for the VS Code extension: it finds the
module of the main class, builds it with the project's build tool and runs the
program. A launch only says how:

- **Gradle** (`launcher = "gradle"`, the default for a lens on a Gradle
  module). Gradle compiles and runs the module.
- **Plain JVM** (`launcher = "jvm"`, the default otherwise). The server builds
  the module, then runs `java` with the module's class path, JDK and working
  directory, adding the VM arguments the project needs, such as
  `--enable-preview`.

<br>

## Launch configurations and launch.json

Every launch configuration of type `kotlin` is launched this way, not only the
lenses.

- `dap.continue()` offers "Launch main class", "Launch main class (Gradle)"
  and "Attach to JVM" out of the box. `dap.configurations = false` leaves
  `dap.configurations.kotlin` / `java` alone.
- Your own entries in `dap.configurations.kotlin` work. Only `mainClass` is
  required:

  ```lua
  {
      type = "kotlin", request = "launch", name = "Run server",
      mainClass = "com.example.ServerKt",
      launcher = "gradle",   -- "gradle" | "jvm"
      args = { "--port", "8080" },
      vmArgs = { "-Xmx1g" },
      env = { APP_ENV = "dev" },
      -- Which code a step does not enter. Default: the JDK, synthetic
      -- methods and class loaders are skipped.
      stepFilters = { skipClasses = { "$JDK", "com.acme.generated.*" } },
  }
  ```

- A `.vscode/launch.json` written for the VS Code extension works unchanged.
  Its `intellij_jvm`, `intellij_gradle` and `intellij_debugger` types go to the
  same adapter, and `file`, `classPaths`, `modulePaths`, `moduleName`,
  `javaExec`, `projectPath`, `sourceSet`, `gradleArgs` and `stepFilters` are
  honored the way the extension honors them.

From Lua, for example to force a plain JVM launch of a Gradle module:

```lua
require("kotlin.dap").run_main({
    mainClass = "com.example.MainKt",
    noDebug = true,     -- false = debug
    launcher = "jvm",   -- "gradle" | "jvm"
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
