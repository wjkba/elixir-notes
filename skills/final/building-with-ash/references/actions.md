# Actions

## Contents
- Anatomy of an action
- Changes (built-in and custom)
- Validations
- Preparations
- Lifecycle hooks: where code runs
- Atomic updates and `require_atomic? false`
- Generic actions
- Upserts and bulk actions
- Notifications and signals
- Errors

## Anatomy of an action

```elixir
actions do
  defaults [:read, :destroy]   # default CRUD; create/update need accept lists: create: [:title]

  create :create do
    primary? true
    accept [:title, :body]
    argument :tag_names, {:array, :string}, default: []

    validate string_length(:title, min: 3)
    change relate_actor(:author)
    change {MyApp.Blog.Post.Changes.AttachTags, []}
  end

  update :publish do
    accept []
    validate attribute_equals(:status, :draft), message: "already published"
    change set_attribute(:status, :published)
    change set_attribute(:published_at, expr(now()))
  end
end
```

- `accept` covers attributes; `argument` covers inputs that aren't stored, or that need transforming first.
- Changes, validations and preparations run in the order you declare them. Use `where [...]` to make one conditional, and `only_when_valid? true` to skip it once the changeset is already invalid.
- To apply one to several actions, put it in a top-level `changes`, `validations` or `preparations` block with `on: [:create, :update]`.

## Changes

Built-in changes: `set_attribute`, `set_new_attribute`, `atomic_update`, `relate_actor`, `manage_relationship`, `cascade_destroy`, `cascade_update`, `optimistic_lock`, `get_and_lock_for_update`, `filter`, `ensure_selected`, `debug_log`.

A custom change looks like this:

```elixir
defmodule MyApp.Blog.Post.Changes.Slugify do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :title) do
      nil -> changeset
      title -> Ash.Changeset.force_change_attribute(changeset, :slug, slugify(title))
    end
  end

  defp slugify(t), do: t |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
end
```

A change with only `change/3` makes update and destroy actions non-atomic. Add an `atomic/3` callback:

```elixir
@impl true
def atomic(_changeset, _opts, _context) do
  {:atomic, %{version: expr(coalesce(version, 0) + 1)}}
end
```

`atomic/3` can return any of these:
- `{:atomic, %{field => expr}}`
- `{:ok, changeset}`: the change works as is, for example because it only adds `after_action` hooks.
- `{:not_atomic, reason}`

Inside an atomic expression, a bare `title` is the value **currently stored in the DB**. Use `^atomic_ref(:title)` for "the new value if it's changing, otherwise the current one".

## Validations

Built-in validations: `present`, `absent`, `attribute_equals`, `attribute_does_not_equal`, `attribute_in`, `argument_equals`, `argument_in`, `compare`, `confirm`, `match`, `one_of`, `string_length`, `byte_size`, `changing`, `negate`, `action_is`, `any`, and `all` (3.31+).

```elixir
validate compare(:ends_at, greater_than: :starts_at)
validate present(:phone) do
  where attribute_equals(:contact_method, :phone)
  message "is required when contact method is phone"
end
```

A custom validation does `use Ash.Resource.Validation`, implements `validate/3` returning `:ok` or `{:error, field: f, message: m}`, and implements `atomic/3` so it works in atomic updates. Validations can't modify the changeset; that is what changes are for.

## Preparations

Preparations modify a read query before it runs:

```elixir
read :recent do
  prepare build(sort: [inserted_at: :desc], limit: 20)
end

preparations do
  prepare build(load: [:author])
end
```

A custom preparation does `use Ash.Resource.Preparation` and implements `prepare(query, opts, context)`.

## Lifecycle hooks: where code runs

| Hook | Runs | Use for |
|---|---|---|
| `before_transaction` | before the DB transaction | slow or external calls that must succeed first |
| `before_action` | inside the transaction, before the write | final data adjustments, related writes |
| `after_action` | inside the transaction, after a successful write | related writes that need the result; returns `{:ok, result}` |
| `after_transaction` | after commit or rollback; gets `{:ok, r}` or `{:error, e}` | emails, external APIs; must return the same shape |

Add hooks from inside a change with `Ash.Changeset.before_action/2` and the related functions. Keep network calls out of the transaction hooks, because they hold a DB connection and lock rows. For anything slow or retryable, enqueue an AshOban job instead.

```elixir
def change(changeset, _opts, context) do
  Ash.Changeset.after_transaction(changeset, fn
    _changeset, {:ok, order} = ok ->
      MyApp.Mailer.order_confirmation(order, scope: context)
      ok

    _changeset, {:error, _} = error ->
      error
  end)
end
```

## Atomic updates and `require_atomic? false`

```elixir
update :increment_views do
  change atomic_update(:view_count, expr(view_count + 1))
end
```

- Setting a value from `expr(now())`, incrementing a counter, or adding `after_action`/`after_transaction` hooks all stay atomic.
- `require_atomic? false` is only needed when a change reads the loaded record (`Ash.Changeset.get_data/2`), a `before_action` or `around_action` hook needs the record, or a validation can't be expressed as an expression.
- Atomic actions are also what makes bulk updates and destroys efficient.

## Generic actions

```elixir
action :monthly_revenue, :decimal do
  argument :month, :date, allow_nil?: false
  run MyApp.Billing.Actions.MonthlyRevenue
end

defmodule MyApp.Billing.Actions.MonthlyRevenue do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, context) do
    {:ok, compute(input.arguments.month, context)}
  end
end
```

Leave out the return type for actions that only return `:ok`. A resource can consist of nothing but generic actions, which is useful for modelling behaviour that has no table behind it.

## Upserts and bulk actions

```elixir
create :upsert_by_email do
  accept [:email, :name]
  upsert? true
  upsert_identity :unique_email
  upsert_fields [:name]
end
```

- To run an action on many records, call `Ash.bulk_create(inputs, Post, :create, actor: a, return_errors?: true)` or its `bulk_update`/`bulk_destroy` counterparts. Update and destroy code interfaces also accept a list or an `Ash.Query`, and then run as bulk operations returning `%Ash.BulkResult{}`.

## Notifications and signals

**PubSub notifications.** These are sent after the transaction commits:

```elixir
use Ash.Resource, notifiers: [Ash.Notifier.PubSub]

pub_sub do
  module MyAppWeb.Endpoint
  prefix "post"
  publish :create, ["created"]
  publish :update, ["updated", :id]   # topic "post:updated:<id>"
end
```

In a LiveView, subscribe only when `connected?(socket)`, then handle `%Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{data: post}}` in `handle_info/2`.

**Signals (3.36+).** When other resources must react to an action and the emitter needs nothing back, declare a signal in a signal module (`use Ash.Signals`), `emit` it from the action, and listen with `signals_in` in the reacting resource. Prefer this to calling other domains from an `after_action` hook. Use a PubSub notifier for at-most-once side effects after commit. Signals need the `:ash_signals` compiler. Read `deps/ash/usage-rules/signals.md` before using them.

## Errors

Every call returns `{:error, class}`, where the class is the worst of the following, in order: `Ash.Error.Forbidden`, `Ash.Error.Invalid`, `Ash.Error.Framework`, `Ash.Error.Unknown`. The individual errors are in `error.errors`. In LiveView forms, errors only show when they have a `field`. See forms.md.
