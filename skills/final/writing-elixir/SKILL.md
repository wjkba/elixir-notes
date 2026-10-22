---
name: writing-elixir
description: Writes idiomatic Elixir 1.18–1.20 outside the Ash and Phoenix specifics — pattern matching, with/pipes, error tuples, structs, OTP processes (GenServer, Task, Supervisor, Registry), Mix tasks and ExUnit tests. Use when writing or fixing plain Elixir modules, processes, scripts or tests, or when compiler or type warnings need resolving.
---

# Writing Elixir

These are the mistakes that still slip through. They're not an Elixir tutorial.

## Language gotchas

- **List index access:** lists don't support `list[i]`. Use `Enum.at/2`, pattern matching or `List` functions.
- **Struct fields:** structs don't implement Access, so `struct[:field]` fails. Use `struct.field` or the module's API (`Ecto.Changeset.get_field/2`).
- **Rebinding inside a block doesn't leak out.** Bind the block's result instead:
  ```elixir
  socket = if connected?(socket), do: assign(socket, :x, 1), else: socket
  ```
- **`else if` doesn't exist.** Use `cond` or `case`. `unless` is deprecated (1.18); write `if !cond`, and `mix format --migrate` rewrites it.
- **Atoms:** never `String.to_atom/1` on external input, because atoms are never garbage collected. Use `String.to_existing_atom/1` or an explicit mapping.
- **Naming:** predicates end in `?` (`valid?/1`). The `is_` prefix is for guards only. Never `is_valid?`.
- **Guards:** use `and`/`or`/`not`, not `&&`/`||`/`!`.
- **JSON:** Elixir 1.18+ has a built-in `JSON` module. In existing code, follow what the project uses (often `Jason`).
- **Type checker (1.19–1.20):** the compiler infers types and reports *verified* bugs, such as an impossible pattern or a missing map key. Treat type warnings as bugs; compile with `mix compile --warnings-as-errors`.

## Control flow and errors

- Prefer function-head pattern matching, then `case`, then `cond`. Use `with` for happy-path chains of `{:ok, _}` steps, and add an `else` only when you need to transform errors.
- Return `{:ok, value}`/`{:error, reason}` for expected failures. Raise for bugs and broken invariants, and provide `!` variants that raise.
- Use `rescue` only at boundaries (third-party code, external input), never for control flow.
- Pipe when the data flows through several steps. Don't pipe a single call, and don't start a pipe from a function call when a value is available.

## Processes

- **Spawn a process only for a runtime reason:** concurrency, isolated state, or fault isolation. Don't create processes just to organise code.
- **Supervise everything long-lived.** Put it in the application's supervision tree; never start a bare `GenServer.start_link` in production code. Name `DynamicSupervisor`/`Registry` children through the child spec: `{DynamicSupervisor, name: MyApp.WorkerSup}`.
- **Run fire-and-forget work under a supervisor:** `Task.Supervisor.start_child/2` (or Oban when it must survive restarts).
- **Use `Task.async_stream/3` for concurrent enumeration with back-pressure.** Set `max_concurrency` and, usually, `timeout: :infinity`.
- **Messages and closures copy data.** Extract the fields you need before you `spawn` or send (`ip = conn.remote_ip`).
- **Process-local state doesn't follow you into a new process.** That covers Logger metadata, Gettext locale and the Ash actor. Capture it before spawning and pass it explicitly.
- **Choosing a state holder:** stateless code → plain module; a simple shared read-mostly value → ETS or `:persistent_term`; complex state, timeouts or serialisation → GenServer.

## Tests (ExUnit)

- Use `async: true` unless the test touches global state.
- Start processes with `start_supervised!/1`, which cleans them up for you.
- Never use `Process.sleep/1` to wait:
  - waiting for a process to exit → `ref = Process.monitor(pid)` + `assert_receive {:DOWN, ^ref, :process, ^pid, _}`
  - waiting for earlier messages to be handled → `:sys.get_state(pid)`
- Running tests: `mix test path/to_test.exs:42`, `mix test --failed`, `mix test --stale`.

## Tooling

- Read a task's docs before using it: `mix help <task>`. For module docs, use `h Module.fun` in IEx, or Tidewave `get_docs` if configured.
- `mix deps.clean --all` is almost never the fix. Reach for `mix deps.get`, `mix deps.compile <dep> --force` or `mix clean` first.
- Before you finish, run `mix format` and `mix compile --warnings-as-errors` (or the project's `mix precommit` alias) and the tests.
