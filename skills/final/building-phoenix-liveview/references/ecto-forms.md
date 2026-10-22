# Ecto forms and Ecto rules (non-Ash code)

In an Ash project, use `AshPhoenix.Form` instead (`building-with-ash` skill, forms reference).

## Form lifecycle

```elixir
def mount(_params, _session, socket) do
  changeset = Blog.change_post(socket.assigns.current_scope, %Post{})
  {:ok, assign(socket, form: to_form(changeset))}
end

def handle_event("validate", %{"post" => params}, socket) do
  changeset =
    Blog.change_post(socket.assigns.current_scope, %Post{}, params)
    |> Map.put(:action, :validate)                    # without an action, errors stay hidden

  {:noreply, assign(socket, form: to_form(changeset))}
end

def handle_event("save", %{"post" => params}, socket) do
  case Blog.create_post(socket.assigns.current_scope, params) do
    {:ok, post} ->
      {:noreply, socket |> put_flash(:info, "Created") |> push_navigate(to: ~p"/posts/#{post.id}")}

    {:error, %Ecto.Changeset{} = changeset} ->
      {:noreply, assign(socket, form: to_form(changeset))}
  end
end
```

- The params key comes from the schema name (`%{"post" => ...}`). For a schemaless form, use `to_form(params, as: :search)`.
- `<.input>` from core components uses `used_input?/1`, so a field's errors only appear after the user has touched it.
- When the form "does nothing" on submit, check the `{:error, changeset}` branch and the changeset's errors before debugging the UI.
- Embedded schemas: every required field the user doesn't edit needs a hidden input, or it's missing from the params.

## Ecto rules

- `cast/3` only the fields the user may change. Set ownership fields (`user_id`, `org_id`) from the scope: `%Post{user_id: scope.user.id}`.
- Read changeset values with `Ecto.Changeset.get_field/2`. Structs don't support `changeset[:field]` access.
- Preload every association a template uses: `Repo.preload(post, :author)` or `preload:` in the query. Otherwise you get N+1 queries or `%Ecto.Association.NotLoaded{}`.
- `field :body, :string` is right for `text` columns too.
- Validations skip nil and unchanged values, so `validate_number/3` has no `:allow_nil` option.
- Run several writes in one transaction with `Repo.transact(fn -> ... {:ok, result} end)`. `Repo.transaction/2` is soft-deprecated as of Ecto 3.13.
- Generate migrations with `mix ecto.gen.migration add_posts_status`, which applies the timestamp and naming conventions.
- In `seeds.exs` and scripts, add `import Ecto.Query` and alias what you use.
