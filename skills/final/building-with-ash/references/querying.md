# Code interfaces and querying

## Contents
- Defining code interfaces
- Calling them
- Read actions, filters and pagination
- Building queries by hand
- Expressions
- Loading data
- Calculations
- Aggregates

## Defining code interfaces

Define them on the domain, which is the public API of your business logic:

```elixir
resources do
  resource MyApp.Blog.Post do
    define :create_post, action: :create, args: [:title]
    define :list_posts, action: :read
    define :list_published_posts, action: :published
    define :get_post, action: :read, get_by: [:id]
    define :get_post_by_slug, action: :read, get_by: [:slug]   # :slug needs an identity
    define :publish_post, action: :publish
    define :post_exists?, action: :exists_by_title, args: [:title] # predicate interface
    define_calculation :reading_time, args: [:body]
  end
end
```

- Use the primary read action with `get_by:` for lookups, and `get?: true` for a custom read action that returns a single record. Add `not_found_error?: false` to get `nil` back instead of an error.
- Positional `args` are for required, identifying inputs. Pass everything else as a map: `create_post!("Title", %{body: b}, opts)`. Prefer that map to defining optional args.
- Each interface generates `fun/…` and `fun!/…`, plus `can_fun?/…` and `can_fun/…` for authorization checks. A name ending in `?` generates `fun/…` (an ok/error tuple) and `fun?/…` (the bare value), and no `!` variant.
- With `extensions: [AshPhoenix]` on the domain, you also get `form_to_<fun>`. See forms.md.

## Calling them

```elixir
Blog.get_post!(id, load: [:author, comments: [:author]], actor: user)

Blog.list_posts!(
  query: [filter: [status: :published], sort: [published_at: :desc], limit: 10],
  load: [:comment_count],
  actor: user
)

Blog.list_published_posts!(page: [limit: 20, offset: 40], actor: user)  # returns %Ash.Page.Offset{}
Blog.list_posts!(stream?: true, actor: user)                           # lazy stream for big reads
```

Options for every call: `actor:`/`scope:`, `tenant:`, `authorize?:`, `load:`, `query:` (passed to `Ash.Query.build/2`: `filter`, `sort`, `limit`, `offset`, `load`), `page:` and `stream?:`. These replace hand-built queries in callers.

## Read actions, filters and pagination

Use a named read action for any filter that has meaning in the business, instead of filtering in callers:

```elixir
read :published do
  argument :author_id, :uuid
  filter expr(status == :published)
  filter expr(is_nil(^arg(:author_id)) or author_id == ^arg(:author_id))
  prepare build(sort: [published_at: :desc])
  pagination offset?: true, keyset?: true, countable: true, default_limit: 20
end
```

## Building queries by hand

Build queries by hand only inside resource modules, changes or preparations, or for complex one-offs:

```elixir
require Ash.Query

Post
|> Ash.Query.for_read(:published, %{author_id: id}, actor: user)
|> Ash.Query.filter(inserted_at > ago(7, :day))
|> Ash.Query.sort(published_at: :desc)
|> Ash.Query.load(author: [:profile])
|> Ash.read!()
```

## Expressions

- `expr/1` is available inside resource DSL. Everywhere else, run `import Ash.Expr` first.
- Pin Elixir values with `^value`.
- Templates: `^actor(:id)`, `^arg(:name)`, `^context(:key)`.
- Functions: `now()`, `ago(7, :day)`, `from_now/2`, `is_nil/1`, `contains/2`, `string_downcase/1`, `type/2`, `if`/`cond`, `fragment/…` (AshPostgres).
- `exists(comments, score > 50)` checks related records. `exists(Report, author_name == parent(name))` checks unrelated ones, and authorization uses the target's primary read action.
- `parent(field)` refers to the outer resource inside relationship filters, `exists`, and aggregate or relationship queries.

## Loading data

- Relationships, calculations and aggregates are `%Ash.NotLoaded{}` until you load them, so load what a template or caller needs.
- Policies of the related resources apply to loaded data, so pass the actor: `Ash.load!(post, [:comments], actor: user)`.
- `Ash.load!(record, fields, lazy?: true)` skips fields that are already loaded.
- To shape a nested load, use `query: [load: [comments: [filter: [approved: true], limit: 5]]]`, or pass a query as the value: `load: [comments: Comment |> Ash.Query.filter(approved) |> Ash.Query.limit(5)]`.
- `strict?: true` loads only the requested fields.

## Calculations

```elixir
calculations do
  calculate :full_name, :string, expr(first_name <> " " <> last_name)
  calculate :overdue?, :boolean, expr(due_at < now() and status != :done)
  calculate :initials, :string, {MyApp.Accounts.User.Calculations.Initials, []}

  calculate :display_name, :string, expr(first_name <> ^arg(:sep) <> last_name) do
    argument :sep, :string, default: " ", constraints: [allow_empty?: true, trim?: false]
  end
end
```

- Expression calculations run in the data layer, so you can filter and sort on them. Prefer them.
- A module calculation uses `use Ash.Resource.Calculation` and implements `load/3` (what it needs), `calculate/3` (takes a list of records and returns a list of values), and optionally `expression/2`.
- To load one with arguments: `load: [display_name: %{sep: ", "}]`.
- The `:auto` type (3.21+) infers the type from the expression.

## Aggregates

```elixir
aggregates do
  count :published_post_count, :posts do
    filter expr(published == true)
  end
  sum :lifetime_value, :orders, :total
  exists :admin?, :roles do
    filter expr(name == "admin")
  end
  first :latest_comment_body, :comments, :body do
    sort inserted_at: :desc
  end
  count :same_name_profiles, MyApp.Profile do      # unrelated resource
    filter expr(name == parent(name))
  end
end
```

- The kinds are `count`, `sum`, `exists`, `first`, `list`, `max`, `min` and `avg`. Load, filter and sort on them like attributes.
- Use `join_filter` to filter intermediate hops of a multi-step path.
- An aggregate can also be inline in an expression: `expr(count(answers, query: [filter: expr(correct)]) * 100 / count(answers))`.
