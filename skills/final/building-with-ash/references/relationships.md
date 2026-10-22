# Relationships

## Defining relationships

```elixir
relationships do
  belongs_to :author, MyApp.Accounts.User do   # adds author_id (uuid by default) to this resource
    allow_nil? false
  end

  has_one :profile, MyApp.Accounts.Profile      # FK lives on the destination

  has_many :published_comments, MyApp.Blog.Comment do
    filter expr(published == true)
    sort inserted_at: :desc
  end

  many_to_many :tags, MyApp.Blog.Tag do
    through MyApp.Blog.PostTag
    source_attribute_on_join_resource :post_id
    destination_attribute_on_join_resource :tag_id
  end
end
```

- Name relationships after their meaning (`:authored_posts`, `:published_comments`), not just after the destination.
- `belongs_to` options: `attribute_type :integer` for non-uuid keys, `public? true` to expose the relationship, and `attribute_public?` for the FK attribute.
- The join resource is an ordinary resource:

```elixir
defmodule MyApp.Blog.PostTag do
  use Ash.Resource, domain: MyApp.Blog, data_layer: AshPostgres.DataLayer

  postgres do
    table "post_tags"
    repo MyApp.Repo
  end

  relationships do
    belongs_to :post, MyApp.Blog.Post, primary_key?: true, allow_nil?: false
    belongs_to :tag, MyApp.Blog.Tag, primary_key?: true, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
```

- For polymorphic relationships, use `Ash.Type.Union` (see the "Polymorphic Relationships" guide).
- Add DB foreign keys for each `belongs_to` in AshPostgres's `references` block (see postgres.md).

## Changing related data from an action

**Declaratively, from an argument.** Use this when the related data comes from user input:

```elixir
update :update do
  accept [:title]
  argument :tags, {:array, :map}
  change manage_relationship(:tags, type: :append_and_remove, on_lookup: :relate)
end

create :create do
  argument :new_tags, {:array, :map}
  change manage_relationship(:new_tags, :tags, type: :create)   # argument name ≠ relationship name
end
```

**Programmatically, inside a custom change:**

```elixir
Ash.Changeset.manage_relationship(changeset, :members, members, type: :append_and_remove)
```

| `type:` | Effect |
|---|---|
| `:append` | relate the given records, keep existing ones |
| `:append_and_remove` | relate the given records, unrelate the missing ones |
| `:remove` | unrelate the given records |
| `:direct_control` | create, update and destroy related records to match the input exactly |
| `:create` | only create new related records |

The `type` presets can be fine-tuned with `on_lookup: :relate`, `on_no_match: :create`, `on_match: :update`, `on_missing: :destroy | :unrelate | :ignore`, and `value_is_key: :name` (for inputs like `["elixir", "ash"]`).

An action with `manage_relationship` makes AshPhoenix infer nested forms automatically (see forms.md).

## Deleting related records

| Need | Use |
|---|---|
| Related records must run their own destroy logic (policies, notifications, hooks) | `change cascade_destroy(:comments)` on the parent's destroy action |
| Plain DB-level cleanup, no Ash logic required | `references do reference :post, on_delete: :delete end` (AshPostgres) |

DB-level `on_delete` bypasses all Ash logic: no validations, policies or notifications run.
