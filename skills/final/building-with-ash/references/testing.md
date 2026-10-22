# Testing Ash code

## Rules

- Test behaviour through **code interfaces**, the same way the app calls it, using `!` variants. Don't use `{:ok, x} = ...`.
- Use `authorize?: false` in tests that aren't about authorization. Policy tests pass a real actor.
- Fields with identities (email, slug, username) need **globally unique values** in tests. Fixed values deadlock or collide when tests run with `async: true`.
- Use the project's DataCase, which sets up the Ecto SQL sandbox. Write `use MyApp.DataCase, async: true`.

## Generators (`Ash.Generator`)

```elixir
defmodule MyApp.Generators do
  use Ash.Generator

  def user(opts \\ []) do
    changeset_generator(MyApp.Accounts.User, :register,
      defaults: [email: sequence(:email, &"user-#{&1}@example.com"), name: "Test User"],
      overrides: opts,
      authorize?: false
    )
  end

  def post(opts \\ []) do
    author = opts[:author] || once(:default_author, fn -> generate(user()) end)
    changeset_generator(MyApp.Blog.Post, :create,
      defaults: [title: sequence(:title, &"Post #{&1}")],
      actor: author,
      overrides: opts
    )
  end
end

# in tests
import MyApp.Generators
user = generate(user())
posts = generate_many(post(author: user), 3)
```

`changeset_generator` runs the real action, so validations and changes apply. `seed_generator` inserts data directly, which is faster but skips action logic. Use it for data that only needs to exist.

## Policy tests

```elixir
test "only the author can update" do
  author = generate(user())
  other = generate(user())
  post = generate(post(author: author))

  assert MyApp.Blog.can_update_post?(author, post)
  refute MyApp.Blog.can_update_post?(other, post)

  assert_raise Ash.Error.Forbidden, fn ->
    MyApp.Blog.update_post!(post, %{title: "x"}, actor: other)
  end
end

test "reads are filtered, not forbidden" do
  # read policies with filter checks drop rows instead of raising
  assert [] == MyApp.Blog.list_drafts!(actor: generate(user()))
end
```

## Error assertions

```elixir
assert {:error, %Ash.Error.Invalid{} = error} = MyApp.Blog.create_post(%{title: ""}, authorize?: false)

# Ash.Test helpers
import Ash.Test
assert_has_error(result, Ash.Error.Invalid, fn
  %Ash.Error.Changes.Required{field: :title} -> true
  _ -> false
end)
```

`Ash.Test.strip_metadata/1` removes `__metadata__` and similar fields, so whole records can be compared with `==`.

## Other

- When testing LiveViews, see the `building-phoenix-liveview` skill. With AshAuthentication, log in by generating a user and storing a token in the session; look for an existing helper in `test/support/` first.
- For signals (3.36+), use `Ash.Signals.Test` (`assert_emits_signal/4`, `react_to_signal/4`).
- For AshOban, `AshOban.schedule_and_run_triggers(MyApp.Blog)` runs triggers synchronously in tests (requires Oban `testing: :manual`).
