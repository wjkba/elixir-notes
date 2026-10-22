# LiveView patterns

## Contents
- Lifecycle skeleton
- Async loading
- Streams
- PubSub
- Components
- Uploads
- Memory checklist

## Lifecycle skeleton

```elixir
defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Blog.subscribe_posts(socket.assigns.current_scope)
    {:ok, assign(socket, page_title: "Posts")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = Map.get(params, "status", "all")
    posts = Blog.list_posts(socket.assigns.current_scope, status: filter)

    {:noreply,
     socket
     |> assign(filter: filter, posts_empty?: posts == [])
     |> stream(:posts, posts, reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Blog.get_post!(socket.assigns.current_scope, id)   # scoped lookup = authorization
    {:ok, _} = Blog.delete_post(socket.assigns.current_scope, post)
    {:noreply, stream_delete(socket, :posts, post)}
  end

  @impl true
  def handle_info({:created, post}, socket), do: {:noreply, stream_insert(socket, :posts, post, at: 0)}
end
```

## Async loading

```elixir
def mount(%{"id" => id}, _session, socket) do
  scope = socket.assigns.current_scope           # extract before the closure

  {:ok,
   socket
   |> assign_async(:stats, fn -> {:ok, %{stats: Reports.stats(scope, id)}} end)
   |> stream_async(:events, fn -> {:ok, Reports.events(scope, id)} end)}   # 1.1+
end
```

```heex
<.async_result :let={stats} assign={@stats}>
  <:loading>Loading…</:loading>
  <:failed :let={_reason}>Could not load stats</:failed>
  {stats.total}
</.async_result>
```

- Use `start_async/3` plus `handle_async/3` when you need control over the result, such as merging it into existing state or retrying.
- Async tasks are linked to the LiveView and cancelled when it exits. Async functions don't run during the static render.
- If the first paint must contain the data (SEO, crawlers), load it synchronously in `mount`, and keep that query cheap.

## Streams

```heex
<div id="posts" phx-update="stream">
  <div id="posts-empty" class="hidden only:block">No posts yet</div>
  <div :for={{dom_id, post} <- @streams.posts} id={dom_id}>{post.title}</div>
</div>
```

| Need | Call |
|---|---|
| append | `stream(socket, :posts, posts)` or `stream_insert(socket, :posts, post)` |
| prepend | `stream_insert(socket, :posts, post, at: 0)` |
| prepend a list in its order | `stream(socket, :posts, Enum.reverse(posts), at: 0)` (each item is inserted at 0 in turn) |
| replace everything (filtering, refresh) | `stream(socket, :posts, posts, reset: true)` |
| update one item | `stream_insert(socket, :posts, post)` (same DOM id → replaced in place) |
| remove | `stream_delete(socket, :posts, post)` or `stream_delete_by_dom_id/3` |
| cap the size | `stream(socket, :posts, posts, at: -1, limit: -50)` (keep the last 50) |

- The parent needs `phx-update="stream"` and an `id`, and every child uses the `dom_id` from the tuple.
- Streams aren't kept in server memory. There's no `Enum` over `@streams.posts`, and no counting it, so keep counts in assigns.
- The `only:block` empty state only works if the empty element is the stream container's only non-stream child.
- Small, bounded lists can stay as plain assigns. In LiveView 1.1+, comprehensions with `:key` track changes per item.
- Streaming Ash data: `AshPhoenix.LiveView.assign_page_and_stream_result/3` handles paginated reads.

## PubSub

```elixir
# context
def subscribe_posts(scope), do: Phoenix.PubSub.subscribe(MyApp.PubSub, "user:#{scope.user.id}:posts")
def broadcast_post(scope, msg), do: Phoenix.PubSub.broadcast(MyApp.PubSub, "user:#{scope.user.id}:posts", msg)
```

- Subscribe only when `connected?(socket)`.
- Broadcast **after** the transaction commits. With Ash, use `Ash.Notifier.PubSub`, which already does this.
- Scope topics by user or tenant so data doesn't leak between them.
- Keep payloads small: send ids or small structs, not large preloaded trees.

## Components

```elixir
attr :post, :map, required: true
attr :rest, :global
slot :actions

def post_card(assigns) do
  ~H"""
  <article id={"post-#{@post.id}"} {@rest}>
    <h2>{@post.title}</h2>
    <div :if={@actions != []}>{render_slot(@actions)}</div>
  </article>
  """
end
```

- A function component has no state. The parent owns the state and handles the events.
- A LiveComponent (`use MyAppWeb, :live_component`) is for UI that needs its own state and events. Target its events with `phx-target={@myself}`, and update it from outside with `send_update/3`.
- `<.portal>` (1.1+) renders content elsewhere in the DOM, for tooltips and modals.
- In LiveView 1.2+, a `<style :type={MyAppWeb.ColocatedCSS}>` tag can hold component-scoped CSS. It needs `Phoenix.LiveView.ColocatedCSS` set up.

## Uploads

```elixir
socket |> allow_upload(:avatar, accept: ~w(.jpg .png), max_entries: 1, max_file_size: 5_000_000)
```

- In the template: `<.live_file_input upload={@uploads.avatar} />`, plus `phx-drop-target={@uploads.avatar.ref}` for drag and drop.
- In the submit handler: `consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry -> {:ok, store(path, entry)} end)`.
- Show `upload_errors/2` for each entry. Use `:external` uploads for direct-to-S3.

## Memory checklist

Everything in assigns lives in the server process for the whole session.

- Lists that grow without bound → streams.
- Full structs with deep preloads when the page renders 3 fields → select or load less.
- Binaries (file contents, images) in assigns → store a reference instead.
- Values needed only for one render → `temporary_assigns` in the `mount` return: `{:ok, socket, temporary_assigns: [results: []]}`.
