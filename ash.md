# Resources
Here we have a minimal resource called `Profile` that has, aside from its primary key, a single string attribute `name`.

```elixir
defmodule Tutorial.Profile do
  use Ash.Resource,
    domain: Tutorial

  attributes do
    uuid_primary_key :id
    attribute :name, :string
  end
end
```

To be able to do anything with this resource, we also need a domain.

```elixir
defmodule Tutorial do
  use Ash.Domain

  resources do
    resource Tutorial.Profile
  end
end
```

Now we can create a changeset for the resource.

```elixir
Tutorial.Profile
|> Ash.Changeset.new()
|> Ash.Changeset.change_attributes(%{name: "John Doe"})
```

# Actions
Actions are much simpler: an action describes a CRUD operation that can be performed on a resource, but using whatever language makes the most sense for your given resource.

For example, you may have a `publish` action on a `BlogPost` resource that changes the resource to be publicly visible. Under CRUD, this would be an `update` operation, but calling it the "publish action" more fully conveys what the operation does.

An action is defined on a resource in an `actions do ... end` block.

```elixir
actions do
  create :create do
    accept [:name]
  end

  # Basic CRUD Operations

Use the ETS data layer to store records in memory.

```elixir
defmodule Tutorial.Profile do
  use Ash.Resource,
    domain: Tutorial,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
    attribute :name, :string
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name]
    end

    update :update do
      accept [:name]
    end
  end
end

defmodule Tutorial do
  use Ash.Domain

  resources do
    resource Tutorial.Profile
  end
end
```

Create records using `for_create/3` and `Ash.create!/1`.

```elixir
Tutorial.Profile
|> Ash.Changeset.for_create(:create, %{name: "Joe Armstrong"})
|> Ash.create!()

Tutorial.Profile
|> Ash.Changeset.for_create(:create, %{name: "Your Name"})
|> Ash.create!()
```

Read all profiles:

```elixir
Tutorial.Profile |> Ash.read!()
```

Filter profiles by name:

```elixir
require Ash.Query

[joe] =
  Tutorial.Profile
  |> Ash.Query.filter(name == "Joe Armstrong")
  |> Ash.read!()
```

`[joe]` extracts the single matching record from the returned list.

Update Joe's name:

```elixir
joe
|> Ash.Changeset.for_update(:update, %{name: "Neil Armstrong"})
|> Ash.update!()
```

Delete the record:

```elixir
Ash.destroy!(joe)
```

| Operation | Function |
|---|---|
| Create | `Ash.create!/1` |
| Read | `Ash.read!/1` |
| Update | `Ash.update!/1` |
| Delete | `Ash.destroy!/1` |

**Remember:** Changesets describe the intended changes; Ash functions execute them.
end
```

Adding that to our `Resource` module from earlier:

```elixir
defmodule Tutorial.Profile do
  use Ash.Resource,
    domain: Tutorial

  attributes do
    uuid_primary_key :id
    attribute :name, :string
  end

  actions do
    create :create do
      accept [:name]
    end
  end
end

defmodule Tutorial do
  use Ash.Domain

  resources do
    resource Tutorial.Profile
  end
end
```

We can now use `for_create/3` to create a changeset.

```elixir
Tutorial.Profile
|> Ash.Changeset.for_create(:create, %{name: "My Name"})
```

# Basic CRUD Operations

Use the ETS data layer to store records in memory.

```elixir
defmodule Tutorial.Profile do
  use Ash.Resource,
    domain: Tutorial,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
    attribute :name, :string
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name]
    end

    update :update do
      accept [:name]
    end
  end
end

defmodule Tutorial do
  use Ash.Domain

  resources do
    resource Tutorial.Profile
  end
end
```

Create records using `for_create/3` and `Ash.create!/1`.

```elixir
Tutorial.Profile
|> Ash.Changeset.for_create(:create, %{name: "Joe Armstrong"})
|> Ash.create!()

Tutorial.Profile
|> Ash.Changeset.for_create(:create, %{name: "Your Name"})
|> Ash.create!()
```

Read all profiles:

```elixir
Tutorial.Profile |> Ash.read!()
```

Filter profiles by name:

```elixir
require Ash.Query

[joe] =
  Tutorial.Profile
  |> Ash.Query.filter(name == "Joe Armstrong")
  |> Ash.read!()
```

`[joe]` extracts the single matching record from the returned list.

Update Joe's name:

```elixir
joe
|> Ash.Changeset.for_update(:update, %{name: "Neil Armstrong"})
|> Ash.update!()
```

Delete the record:

```elixir
Ash.destroy!(joe)
```

| Operation | Function |
|---|---|
| Create | `Ash.create!/1` |
| Read | `Ash.read!/1` |
| Update | `Ash.update!/1` |
| Delete | `Ash.destroy!/1` |

**Remember:** Changesets describe the intended changes; Ash functions execute them.


