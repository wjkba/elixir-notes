# Testing LiveViews and controllers

## Rules

- Use `Phoenix.LiveViewTest`. Target elements by the stable DOM `id`s you added in templates, and assert outcomes with `has_element?/2,3`, not raw HTML strings or exact text.
- Plan the tests first, then build up from "renders" to "interactions" to "edge cases". Keep each test file focused on one LiveView.
- Use the generated `ConnCase` setup for an authenticated user (`setup :register_and_log_in_user`) or the project's own helper. Create data through context or domain functions, not through `Repo` inserts that skip business logic.
- Don't use `Process.sleep`. Call `render(view)` to sync with the LiveView process, and `render_async(view)` to wait for async assigns.

## Patterns

```elixir
test "creates a post", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/posts/new")

  assert view
         |> form("#post-form", post: %{title: ""})
         |> render_change() =~ "can&#39;t be blank"

  view |> form("#post-form", post: %{title: "Hello"}) |> render_submit()
  {path, _flash} = assert_redirect(view)
  assert path =~ ~r"/posts/.+"
end

test "deletes from the stream", %{conn: conn, post: post} do
  {:ok, view, _} = live(conn, ~p"/posts")
  view |> element("#posts-#{post.id} button[phx-click=delete]") |> render_click()
  refute has_element?(view, "#posts-#{post.id}")
end

test "patches the URL when filtering", %{conn: conn} do
  {:ok, view, _} = live(conn, ~p"/posts")
  view |> element("#filter-published") |> render_click()
  assert_patch(view, ~p"/posts?status=published")
end

test "loads stats asynchronously", %{conn: conn} do
  {:ok, view, _} = live(conn, ~p"/dashboard")
  assert render_async(view) =~ "Total"
end
```

More helpers:
- `render_hook(view, "event", params)`
- `file_input/4` + `render_upload/3`
- `follow_redirect/2`
- `page_title/1`
- `live_children/1`
- `open_browser(view)` to see the page while debugging

## Debugging selectors

LiveViewTest uses LazyHTML (1.1+), which supports modern CSS selectors such as `:has()` and `:is()`. To see what actually rendered:

```elixir
view |> render() |> LazyHTML.from_fragment() |> LazyHTML.filter("#post-form") |> IO.inspect()
```

## Controllers

```elixir
conn = get(conn, ~p"/posts")
assert html_response(conn, 200) =~ "Posts"
assert %{"data" => _} = json_response(get(conn, ~p"/api/posts"), 200)
```

Test warnings in LiveView 1.2+ (duplicate ids, forms without ids) are set with `config :phoenix_live_view, :test_warnings, duplicate_id: :raise, missing_form_id: :warn`.
