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

# Attributes

A `Ticket` resource represents a helpdesk ticket with a subject, description, status, and timestamps.

```elixir
defmodule Tutorial.Support.Ticket do
  use Ash.Resource,
    domain: Tutorial.Support,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read]

    create :create do
      accept [:subject, :description, :status]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string, allow_nil?: false
    attribute :description, :string

    attribute :status, :atom do
      constraints one_of: [:open, :closed]
      default :open
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end
end

defmodule Tutorial.Support do
  use Ash.Domain

  resources do
    resource Tutorial.Support.Ticket
  end
end
```

- **Subject:** Required; cannot be `nil`.
- **Description:** Optional string.
- **Status:** Must be `:open` or `:closed`. Defaults to `:open` and cannot be `nil`.
- **Timestamps:** `created_at` tracks creation; `updated_at` tracks the last update.

**Create a ticket**

```elixir
Tutorial.Support.Ticket
|> Ash.Changeset.for_create(:create, %{
  subject: "This is the subject"
})
|> Ash.create!()
```

**Create a closed ticket**

```elixir
Tutorial.Support.Ticket
|> Ash.Changeset.for_create(:create, %{
  subject: "This is the subject",
  status: :closed
})
|> Ash.create!()
```

**Validation examples**

- Omitting `subject` causes a validation error.
- Setting `status: :pending` causes a validation error because it is not an allowed value.

**Get the latest created ticket**

Sort by `created_at` in descending order, limit the results to one, and return the single record.

```elixir
Tutorial.Support.Ticket
|> Ash.Query.sort(created_at: :desc)
|> Ash.Query.limit(1)
|> Ash.read_one!()
```

# Custom Actions

Custom actions give operations meaningful names and let you control their behavior and which attributes can be changed.

- `:open` — Creates a ticket, accepting only `:subject` and `:description`. The status defaults to `:open`.
- `:close` — Updates a ticket's status to `:closed` without accepting any input attributes.

Define custom actions inside the `actions` block:

```elixir
actions do
  defaults [:read]

  create :open do
    accept [:subject, :description]
  end

  update :close do
    accept []
    change set_attribute(:status, :closed)
  end
end
```

**Open a ticket**

```elixir
ticket =
  Tutorial.Support.Ticket
  |> Ash.Changeset.for_create(:open, %{subject: "My Subject"})
  |> Ash.create!()
```

The `:open` action does not allow setting `:status` directly because it only accepts `:subject` and `:description`.

**Close a ticket**

```elixir
ticket
|> Ash.Changeset.for_update(:close)
|> Ash.update!()
```

The `:close` action automatically sets the status to `:closed` using `change set_attribute(:status, :closed)`.

**Key takeaway:** Custom actions define not only what an operation is called, but also what attributes it accepts and what changes it performs.


# Relationships

Use a `relationships do` block to define relationships between resources.

A `belongs_to` relationship connects a ticket to one representative. Ash automatically creates the `representative_id` attribute.

```elixir
relationships do
  belongs_to :representative, Tutorial.Support.Representative
end
```

Add `:representative_id` to the ticket's create action's accepted attributes so you can assign a representative when creating a ticket.

```elixir
create :create do
  accept [:subject, :description, :status, :representative_id]
end
```

Create a representative:

```elixir
joe =
  Tutorial.Support.Representative
  |> Ash.Changeset.for_create(:create, %{name: "Joe Armstrong"})
  |> Ash.create!()
```

Create a ticket and assign Joe as its representative:

```elixir
Tutorial.Support.Ticket
|> Ash.Changeset.for_create(:create, %{
  subject: "My spoon is too big!",
  representative_id: joe.id
})
|> Ash.create!()
|> Ash.load!([:representative])
```

`Ash.load!/2` loads the related representative so you can access it through the ticket's `representative` relationship.

**Key takeaway:** Define relationships with `belongs_to`, and accept the generated foreign key in the action when you want to assign the relationship directly.


# Code Interfaces

Code interfaces simplify CRUD operations by letting you call functions directly instead of manually building changesets.

Define them inside the domain's `resources` block.

```elixir
resources do
  resource Tutorial.Support.Ticket do
    define :assign_ticket, args: [:representative_id], action: :assign
    define :open_ticket, args: [:subject, :description], action: :open
  end

  resource Tutorial.Support.Representative do
    define :create_representative, args: [:name], action: :create
  end
end
```

**Create a representative**

```elixir
joe = Tutorial.Support.create_representative!(%{name: "Joe Armstrong"})
```

**Open a ticket**

```elixir
ticket =
  Tutorial.Support.open_ticket!(%{
    subject: "My subject",
    description: "My description"
  })
```

**Assign a representative to a ticket**

The `:assign` action must accept `:representative_id`.

```elixir
Tutorial.Support.assign_ticket!(ticket, %{representative_id: joe.id})
```

**Key takeaway:** Code interfaces provide convenient, named functions for calling resource actions without manually creating changesets.


# Aggregates

Aggregates summarize related records. Ash supports `count`, `first`, `sum`, and `list`.

**1. Define the relationship**

In the `Representative` resource, add the inverse relationship to access its tickets.

```elixir
relationships do
  has_many :tickets, Tutorial.Support.Ticket
end
```

**2. Define the aggregate**

Count the representative's open tickets using a filter.

```elixir
aggregates do
  count :count_of_open_tickets, :tickets do
    filter expr(status == :open)
  end
end
```

Without the filter, the aggregate counts **all tickets**, regardless of status.

**3. Create tickets**

Create a representative and four tickets, assigning three to Joe.

```elixir
joe = Tutorial.Support.Representative.create!("Joe Armstrong")

[
  %{subject: "I can't see my eyes!"},
  %{subject: "I can't find my hand!", representative_id: joe.id},
  %{subject: "My fridge is flying away!", representative_id: joe.id},
  %{subject: "My bed is invisible!", representative_id: joe.id}
]
|> Ash.bulk_create(Tutorial.Support.Ticket, :open, return_records?: true)
```

**4. Close the last ticket assigned to Joe**

```elixir
require Ash.Query

[last_ticket] =
  Tutorial.Support.Ticket
  |> Ash.Query.filter(representative_id == ^joe.id)
  |> Ash.Query.sort(created_at: :desc)
  |> Ash.Query.limit(1)
  |> Ash.read!()

Tutorial.Support.Ticket.close!(last_ticket)
```

**5. Query the aggregate**

Load the aggregate onto Joe and access its value.

```elixir
joe = Ash.load!(joe, [:count_of_open_tickets])
joe.count_of_open_tickets
```

**Result:** `2`

Joe had three assigned tickets, but one was closed, leaving two open tickets.

**Key takeaway:** Aggregates calculate summary values over related records, and filters let you restrict which records are included.
