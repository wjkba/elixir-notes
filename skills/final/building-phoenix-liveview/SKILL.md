---
name: building-phoenix-liveview
description: Builds Phoenix 1.8 web code with LiveView 1.x — routers, controllers, function components, HEEx templates, LiveViews, streams, async assigns, forms, PubSub, JS hooks, uploads and LiveView tests. Use when editing anything under lib/*_web/ (`*_live.ex`, `.heex`, components, router, layouts) or debugging LiveView behaviour such as forms not saving, lists not updating, or double-loaded data.
---

# Building Phoenix + LiveView

## Before writing code

1. Check `phoenix` and `phoenix_live_view` in `mix.lock`. This skill was written against Phoenix 1.8 and LiveView 1.2; "(1.1+)" and "(1.2+)" mark features that need those versions.
2. Read the project's `core_components.ex` and `layouts.ex`, and use what they provide (`<.input>`, `<.button>`, `<.table>`, `<.icon>`, `<.header>`) instead of new markup.
3. If the project's `AGENTS.md`/`CLAUDE.md` came from `phx.new`, its rules apply. This skill adds to them and corrects a few.
4. In an Ash project (`use Ash.Resource` present), also use the `building-with-ash` skill: data access goes through domain code interfaces, and forms use `AshPhoenix.Form`.

## Phoenix 1.8 conventions

- Wrap every LiveView template in `<Layouts.app flash={@flash} current_scope={@current_scope}>`. `<.flash_group>` belongs only in `layouts.ex`.
- **Scopes.** The signed-in context is `@current_scope` (with `current_scope.user`), set by the generated `UserAuth` on_mount hooks. Generated context functions take the scope as their first argument. If you get a "no `current_scope` assign" error, move the route into the correct `live_session` and pass `current_scope` to the layout.
- Router `scope "/admin", MyAppWeb.Admin do` already prefixes module aliases, so `live "/users", UserLive.Index` resolves to `MyAppWeb.Admin.UserLive.Index`. Don't add your own alias.
- Write paths with verified routes: `~p"/posts/#{post.id}"`.
- Icons: `<.icon name="hero-x-mark" class="size-5" />`. HTTP client: `Req`, which is already a dependency.
- **Assets.** Tailwind v4 is configured in `app.css` (there's no `tailwind.config.js`). Only the `app.js` and `app.css` bundles exist, so import vendor JS and CSS into them; never link external `<script src>` tags.
- Passing your own `class` to `<.input>` replaces its default classes entirely.
- Before finishing, run `mix precommit` (compile with warnings as errors, format, unused deps, tests).

## HEEx rules

- **Interpolation:** `{@value}` in attributes and text. Block constructs (`if`, `case`, `cond`, `for`) in a tag body use `<%= ... %>`. `<%= %>` is not allowed inside attributes.
- **Conditionals and loops:** prefer the `:if` and `:for` attributes. Elixir has no `else if`, so use `cond`/`case`. In LiveView 1.1+, add `:key={item.id}` to `:for` so diffs stay small.
- **Classes:** a list, `class={["base", @active && "font-bold", if(@x, do: "a", else: "b")]}`. Inline `if` needs parentheses.
- **Comments:** `<%!-- ... --%>`. To show literal `{`/`}` (code samples), set `phx-no-curly-interpolation` on the parent tag.
- **Forms:** `<.form for={@form} id="post-form" phx-change="validate" phx-submit="save">` with `<.input field={@form[:title]}>`, where `@form` comes from `to_form/2`. Never pass a changeset to the template, and never use `<.form let={f}>` or `Phoenix.HTML.form_for`.
- **DOM ids:** give forms, stream containers, hooked elements and anything tests target a unique, stable `id`. Since LiveView 1.2, tests warn about a `phx-change` form without an `id`, because form recovery needs one.
- **Scripts:** no raw `<script>` tags. Use a colocated hook (see references/js-interop.md).
- **Component attributes:** declare them with `attr`/`slot`. For pass-through HTML attributes, use `attr :rest, :global` and `{@rest}`.

## LiveView rules

1. **`mount/3` runs twice**: once for the static HTTP render and again over the websocket. Use `assign_async`/`start_async` for slow loads, run side effects only `if connected?(socket)`, and subscribe to PubSub only when connected.
2. **URL-dependent state goes in `handle_params/3`**, which runs on mount and on every patch. `mount` holds state that doesn't depend on the URL.
3. **Use streams for collections that grow or are large.** Streams aren't enumerable. To filter, re-fetch and `stream(..., reset: true)`. To prepend, use `at: 0` (`at: -1` *appends*). Keep counts and empty-state flags in separate assigns. When an assign used inside a stream item changes, `stream_insert` the item again. Details: references/liveview.md.
4. **Never capture `socket` in async closures.** Copy the values you need first (`scope = socket.assigns.current_scope`), because the closure copies everything it references.
5. **Keep business logic out of callbacks.** `handle_event` calls a context or domain function, then assigns the result. Never pass the socket to business code.
6. **Re-authorize in every event.** Clients can send any event with any params. Load records through the current scope or actor (`Blog.get_post!(scope, id)`), never by a bare id from params.
7. **Handle form failures explicitly.** Match `{:error, %Ecto.Changeset{} = cs}` (or `{:error, form}` with AshPhoenix) and re-assign the form. Treat other errors separately, otherwise they disappear silently.
8. **Navigation:** `<.link navigate={...}>` or `push_navigate` between LiveViews, `<.link patch={...}>` or `push_patch` within one LiveView, `href`/`redirect` to leave the `live_session`. `live_redirect`, `live_patch` and `phx-update="append"`/`"prepend"` are removed or deprecated.
9. **Prefer function components.** Use a LiveComponent only when a piece of UI needs its own state *and* its own event handling.
10. **Use `assign/3` for values that must refresh on every mount** (current user, locale). `assign_new/3` skips its function when the key already exists.

## References

| Task | File |
|---|---|
| Lifecycle, async loading, streams, PubSub, navigation, components, uploads | [references/liveview.md](references/liveview.md) |
| Forms with Ecto changesets, Ecto rules (non-Ash projects) | [references/ecto-forms.md](references/ecto-forms.md) |
| JS hooks, colocated hooks and CSS, JS commands, push_event | [references/js-interop.md](references/js-interop.md) |
| LiveView and controller tests | [references/testing.md](references/testing.md) |

## Source of truth

1. Tidewave MCP if configured (`get_docs`, `project_eval`).
2. Version-exact rules: `deps/phoenix/usage-rules/*.md`, and the project's generated `AGENTS.md`.
3. `mix help phx.gen.live` and other generator help; `mix phx.routes`.
4. `https://hexdocs.pm/phoenix_live_view/` and `https://hexdocs.pm/phoenix/`. Fetch one module or guide page at a time.
