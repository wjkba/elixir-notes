# LiveView checklist

Each item: what to look for → why it matters → grep leads.

## Security
- **Records loaded by a bare id from event or URL params without the current user, scope or actor** → IDOR. Leads: `get!(id`, `Repo.get`, `"id" =>` in `handle_event`/`handle_params`.
- **`authorize?: false` or a missing `actor:`/`scope:` in web-layer calls** → policies skipped. Leads: `authorize?: false`, domain calls without `actor:`.
- **Ownership fields (`user_id`, `org_id`, `role`) cast or accepted from params** → mass assignment. Leads: `cast(` lists, `accept` lists.
- **Routes outside the authenticated `live_session`, or the wrong on_mount hook** → check the router.

## Lifecycle
- **Expensive or side-effecting work in `mount/3` without `connected?/1`, `assign_async` or `start_async`** → it runs twice. Leads: domain/Repo calls in `mount`.
- **PubSub subscribe without `if connected?(socket)`** → wasted subscriptions on the static render.
- **URL-dependent loading in `mount` instead of `handle_params`** → stale data after `patch`.
- **`socket` or `socket.assigns` referenced inside `assign_async`/`start_async`/`Task` closures** → the whole socket is copied.
- **`assign_new` for values that must refresh on every mount** (current user, locale).

## Memory (build the assigns inventory)
For each `assign(`/`assign_new(`/`stream(` call, record the key, what it holds, and whether it's bounded.
- **Unbounded lists in assigns** → use streams. Leads: `assign(.*list_`, `assign(.*Repo.all`, `read!` results.
- **Full records with deep preloads or loads when the template uses only a few fields.**
- **Binaries or file contents in assigns.**
- **One-shot data kept forever** → `temporary_assigns`.
- **Assigns never read by the template or any callback** → remove them (compare the keys with `@key` usages in the `.heex`/`~H`).

## Streams
- **`at: -1` used with intent to prepend** (it appends). **A list inserted `at: 0` without `Enum.reverse`.**
- **`Enum.*` over `@streams.x`, or counting a stream** → it isn't enumerable.
- **Missing `phx-update="stream"`, a container `id`, or children not using the stream `dom_id`.**
- **An assign that affects stream items changes without `stream_insert` re-inserting the affected items.**

## Forms
- **Changeset passed to the template, `<.form let={f}>`, or `Phoenix.HTML.form_for`.**
- **A `phx-change` form without an `id`** → breaks form recovery; warns in 1.2+.
- **The `{:error, _}` branch doesn't re-assign the form, or swallows errors that aren't changeset errors.**
- **Ash: errors that have no `field` are never shown** (see AshPhoenix `raw_errors`).

## Architecture and deprecations
- **Business logic, `Repo.*` or `Ash.*` calls in `handle_event`** instead of a context or domain interface.
- **A LiveComponent with no own state or events** → turn it into a function component.
- **Deprecated or removed APIs:** `live_redirect`, `live_patch`, `phx-update="append|prepend"`, raw `<script>` in HEEx, `Phoenix.View`, `~E`.
- **Phoenix 1.8:** templates not wrapped in `<Layouts.app>`, or `<.flash_group>` used outside layouts.
