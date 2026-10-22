# AshPhoenix forms

## Contents
- Building forms from code interfaces
- LiveView lifecycle
- Nested forms
- Union-type forms
- When submit fails but no error shows

Don't use `Ecto.Changeset` or `Phoenix.HTML.FormData` on changesets in an Ash app. Forms are `AshPhoenix.Form`, wrapped with `to_form/1`.

## Building forms from code interfaces

Add the extension to the domain, and every `define` gets a matching `form_to_<name>` function:

```elixir
use Ash.Domain, extensions: [AshPhoenix]

resources do
  resource MyApp.Blog.Post do
    define :create_post, action: :create
    define :update_post, action: :update
  end
end

# Optional: positional args for values the user must not edit (from the URL, the session, ...).
# In `form_to_*` functions, `args` from `define` is ignored unless you set it here.
forms do
  form :create_post, args: [:blog_id]
end
```

```elixir
# create
form = MyApp.Blog.form_to_create_post(blog.id, actor: user) |> to_form()
# update: load everything the form shows (nested data included) before building it
post = MyApp.Blog.get_post!(id, load: [:tags], actor: user)
form = MyApp.Blog.form_to_update_post(post, actor: user) |> to_form()
```

Without the extension: `AshPhoenix.Form.for_create(Post, :create, actor: user)` / `for_update(post, :update, actor: user)`.

> The upstream usage-rules example calls the result `MyApp.Accounts.register_with_password(email, ...)`. The generated function is actually `form_to_register_with_password(email, ...)`.

## LiveView lifecycle

```elixir
def mount(_params, _session, socket) do
  form = MyApp.Blog.form_to_create_post(actor: socket.assigns.current_user) |> to_form()
  {:ok, assign(socket, form: form)}
end

def handle_event("validate", %{"form" => params}, socket) do
  {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
end

def handle_event("save", %{"form" => params}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
    {:ok, post} ->
      {:noreply,
       socket
       |> put_flash(:info, "Saved")
       |> push_navigate(to: ~p"/posts/#{post.id}")}

    {:error, form} ->
      {:noreply, assign(socket, form: form)}
  end
end
```

```heex
<.form for={@form} id="post-form" phx-change="validate" phx-submit="save">
  <.input field={@form[:title]} label="Title" />
  <.button phx-disable-with="Saving...">Save</.button>
</.form>
```

- The params key is `"form"` by default. Change it with `as: "post"` when building the form.
- Pass `actor`/`scope` when **building** the form. `submit/2` reuses them.

## Nested forms

AshPhoenix infers nested forms from `manage_relationship` arguments on the action:

```elixir
create :create do
  accept [:name]
  argument :locations, {:array, :map}
  change manage_relationship(:locations, type: :create)
end
```

```heex
<.inputs_for :let={loc} field={@form[:locations]}>
  <.input field={loc[:name]} />
  <.button type="button" phx-click="remove-form" phx-value-path={loc.name}>Remove</.button>
</.inputs_for>
<.button type="button" phx-click="add-form" phx-value-path={@form.name <> "[locations]"}>Add</.button>
```

```elixir
def handle_event("add-form", %{"path" => path}, socket),
  do: {:noreply, assign(socket, form: AshPhoenix.Form.add_form(socket.assigns.form, path))}

def handle_event("remove-form", %{"path" => path}, socket),
  do: {:noreply, assign(socket, form: AshPhoenix.Form.remove_form(socket.assigns.form, path))}
```

For update forms, load the related data first, or the nested forms start out empty.

## Union-type forms

For a union field, render a `_union_type` select inside `inputs_for`. When it changes, `remove_form(path)` and then `add_form(path, params: %{"_union_type" => new_type})`. Branch on `fc.params["_union_type"]` to render the fields for each member.

## When submit fails but no error shows

A form only shows errors that implement `AshPhoenix.FormData.Error` **and** have a `field` that is rendered.

1. Inspect everything: `AshPhoenix.Form.raw_errors(form, for_path: :all)`.
2. To see what the form *will* display: `AshPhoenix.Form.errors(form, for_path: :all)`.
3. Typical causes:
   - The failing field isn't in the form.
   - A policy returned Forbidden.
   - A custom change returned an error without a `field`.
   - Params were sent under the wrong key.
4. Show errors that aren't tied to a field with a flash message or a notice on the form.
