# Ash in production

Supplement to `ash.md`. It keeps the helpdesk example (`Tutorial.Support`) and grows it into what a production codebase looks like.
Versions: Ash 3.x, AshPostgres 2.x, AshPhoenix 2.x.

The running example:

- `Tutorial.Accounts.User`: `role` is one of `:admin`, `:manager`, `:representative`, `:customer`
- `Tutorial.Support.Ticket`: subject, description, status, priority, customer, representative
- `Tutorial.Support.Representative`, `Tutorial.Support.Comment`, `Tutorial.Support.Tag`

# Project layout

Each domain gets one module plus a folder. Resources sit in the folder, and their helper modules go in subfolders named after what they are.

```
lib/tutorial/
  support.ex                          # Tutorial.Support (domain)
  support/
    ticket.ex                         # Tutorial.Support.Ticket (resource)
    comment.ex
    calculations/resolution_time.ex   # use Ash.Resource.Calculation
    changes/detect_language.ex        # use Ash.Resource.Change
    validations/ticket_open.ex        # use Ash.Resource.Validation
    types/priority.ex                 # custom Ash types
    workers/import_tickets_worker.ex  # Oban workers
  policy_checks/is_staff.ex           # shared policy checks
  system_actor.ex
```

- Tests sit next to the file they test: `ticket.ex` → `ticket_test.exs`.
- Web code (`lib/tutorial_web`) calls domain functions. Domain code never depends on web modules.

# AshPostgres resource

A real resource adds a data layer, a table, and an authorizer.

```elixir
defmodule Tutorial.Support.Comment do
  use Ash.Resource,
    otp_app: :tutorial,
    domain: Tutorial.Support,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "comments"
    repo Tutorial.Repo

    references do
      reference :ticket, on_delete: :delete    # FK ON DELETE CASCADE
      reference :author, on_delete: :nilify
    end
  end

  attributes do
    uuid_v7_primary_key :id, writable?: true   # time-ordered UUID; client may send it
    attribute :body, :string, allow_nil?: false, public?: true
    create_timestamp :created_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    belongs_to :ticket, Tutorial.Support.Ticket, allow_nil?: false, public?: true
    belongs_to :author, Tutorial.Accounts.User, public?: true
  end
end
```

- `on_delete:` takes `:delete`, `:restrict`, or `:nilify`.
- `public? true` exposes a field to external interfaces (RPC, JSON, GraphQL). Everything is private by default.
- `writable?: true` on the primary key lets the client generate ids, which is useful for optimistic UI.
- `description` on attributes and actions shows up in generated docs and API types.

# Migrations

You never write migrations by hand. Ash diffs your resources against snapshots stored in `priv/resource_snapshots`.

```bash
mix ash.codegen add_ticket_priority   # generate migration + snapshot from resource changes
mix ash.migrate                       # run pending migrations
mix ash.setup                         # create + migrate
mix ash.codegen --check               # CI: fail if resources changed but no migration was generated
```

**Key takeaway:** change the resource first, then run `ash.codegen`. The resource is the source of truth for the schema.

# Attribute extras

```elixir
attribute :email, :ci_string do          # case-insensitive string (citext)
  allow_nil? false
  public? true
end

attribute :hashed_password, :string do
  sensitive? true                        # redacted in logs/inspect
end

attribute :external_id, :string,
  constraints: [match: ~r/^EXT-\d+$/]    # regex constraint
```

Reusable enum type:

```elixir
defmodule Tutorial.Support.Types.Priority do
  use Ash.Type.Enum, values: [:low, :normal, :high, :urgent]
end

attribute :priority, Tutorial.Support.Types.Priority, default: :normal, allow_nil?: false
```

# Actions in depth

## Action options you see everywhere

```elixir
actions do
  default_accept [:subject, :description]   # accept list for default create/update
  defaults [:read, :update]

  update :reprioritize do
    description "Change the priority of a ticket."
    accept [:priority]
    primary? true    # used when Ash needs "the" update (e.g. manage_relationship)
    public? true     # may be exposed through RPC/API extensions
  end
end
```

## accept vs argument

- `accept`: attributes written straight to the record.
- `argument`: input that is *not* an attribute. Changes, validations, and filters use it.

```elixir
create :open do
  accept [:subject, :description, :representative_id]
  require_attributes [:description]          # accepted AND required for this action only

  # customers may only pick a subset of priorities
  argument :priority, :atom do
    default :normal
    constraints one_of: [:low, :normal]
  end

  change set_attribute(:priority, arg(:priority))
  change relate_actor(:customer)             # belongs_to :customer := actor
end
```

## Read actions with arguments, filters, and pagination

```elixir
read :list do
  argument :status, :atom, allow_nil?: true

  # optional filter: if no status is given, return everything
  filter expr(is_nil(^arg(:status)) or status == ^arg(:status))

  pagination keyset?: true, required?: false
end

read :search do
  argument :query, :string, allow_nil?: true
  pagination offset?: true, default_limit: 50, countable: :by_default, required?: false

  # apply only when the argument is present
  prepare build(filter: expr(ilike(subject, ^arg(:query)))) do
    where present(:query)
  end
end

read :mine do
  filter expr(customer_id == ^actor(:id))
  prepare build(sort: [created_at: :desc])
end

read :by_external_id do
  get_by :external_id               # shorthand: argument + filter + get? true
end
```

- `^arg(:x)` reads an action argument and `^actor(:field)` reads a field of the actor. Both only work inside `expr`.
- `get? true` makes a read return one record instead of a list.
- Callers paginate with `page: [limit: 20, offset: 40]`, or turn it off with `page: false`.

## Generic actions

Use a generic action for anything that isn't CRUD on one record: computations, external calls, orchestration.

```elixir
action :stats, :map do
  argument :from, :date, allow_nil?: false
  argument :to, :date, allow_nil?: false

  run fn input, ctx ->
    {:ok, Tutorial.Support.Stats.compute(input.arguments.from, input.arguments.to, actor: ctx.actor)}
  end
end

# returning a record of the resource itself
action :summarize, :struct do
  constraints instance_of: __MODULE__
  argument :ticket, :struct, constraints: [instance_of: __MODULE__]
  run Tutorial.Support.Actions.Summarize
end
```

Move longer `run` bodies into a module:

```elixir
defmodule Tutorial.Support.Actions.Summarize do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(%{arguments: %{ticket: ticket}}, _opts, %{actor: actor}) do
    with {:ok, ticket} <- Ash.load(ticket, [comments: [:author]], actor: actor),
         {:ok, summary} <- Tutorial.LLM.summarize(ticket) do
      ticket
      |> Ash.Changeset.for_update(:update_summary)
      |> Ash.Changeset.force_change_attribute(:summary, summary)
      |> Ash.update(actor: actor)
    end
  end
end
```

## require_atomic? and transaction?

```elixir
update :detect_language do
  accept []
  require_atomic? false   # this action uses a non-atomic (function/module) change
  transaction? false      # don't hold a DB transaction while calling an HTTP API
  change Tutorial.Support.Changes.DetectLanguage
end
```

- Updates and destroys try to run as a single atomic SQL statement by default. If a change or validation can't be expressed atomically (anonymous fn, `before_action`, a lookup), compilation or the call fails until you add `require_atomic? false`.
- Set `transaction? false` on any action that does slow I/O.

# Built-in changes and validations

```elixir
change set_attribute(:status, :closed)
change set_attribute(:priority, arg(:priority))
change set_attribute(:author_id, expr(^actor(:id)))
change relate_actor(:representative)              # belongs_to :representative := actor
change cascade_destroy(:comments)                 # destroy related records through their action
change after_transaction(&send_confirmation/3)    # runs after COMMIT (emails, notifications)

validate confirm(:password, :password_confirmation)
validate compare(:due_at, greater_than: &DateTime.utc_now/0),
  message: "Due date must be in the future."
validate attribute_equals(:status, :open)
validate attributes_present([:representative_id]) do
  message "Assign a representative before starting work."
end
validate absent(:closed_at)

# conditional validation
validate present(:resolution),
  where: [attribute_equals(:status, :closed)]
```

## manage_relationship

Creates, updates, or links related records from an argument, inside one action and one transaction.

```elixir
create :open do
  accept [:subject, :description]
  argument :comments, {:array, :map}

  # create child comments together with the ticket
  change manage_relationship(:comments, type: :create)
end

update :set_tags do
  argument :tags, {:array, :map}, allow_nil?: false

  # link existing tags by unique name, create missing ones, unlink the rest
  change manage_relationship(:tags,
           type: :append_and_remove,
           on_no_match: :create,
           use_identities: [:unique_name])
end
```

- Two-arg form `(:arg, :relationship)` when the names differ.
- Common types: `:create`, `:append` (link existing), `:append_and_remove`, `:direct_control` (full sync of a list).

# Custom changes

`use Ash.Resource.Change`. You get the changeset and return a changeset, usually after attaching a hook.

```elixir
defmodule Tutorial.Support.Changes.DetectLanguage do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      case LanguageClient.detect(changeset.data.description) do
        {:ok, language} ->
          Ash.Changeset.force_change_attribute(changeset, :language, language)

        {:error, reason} ->
          Ash.Changeset.add_error(changeset, "Language detection failed: #{inspect(reason)}")
      end
    end)
  end
end
```

Enqueue a job only once the record exists:

```elixir
defmodule Tutorial.Support.Changes.EnqueueSummary do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, ticket ->
      case %{"ticket_id" => ticket.id} |> SummarizeTicketWorker.new() |> Oban.insert() do
        {:ok, _job} -> {:ok, ticket}
        {:error, error} -> {:error, error}   # rolls back the whole action
      end
    end)
  end
end
```

| Hook | When it runs |
|---|---|
| `change/3` body | while building the changeset (no DB yet) |
| `before_action` | inside the transaction, right before the write |
| `after_action` | inside the transaction, after the write; receives the record |
| `after_transaction` | after commit or rollback; receives `{:ok, record}` or `{:error, e}` |

- `force_change_attribute` writes a field even if the action doesn't `accept` it.
- `add_error` fails the action without raising.

# Custom validations

```elixir
defmodule Tutorial.Support.Validations.TicketOpen do
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def supports(_opts), do: [Ash.ActionInput]   # usable on generic actions

  @impl true
  def validate(input, _opts, context) do
    ticket_id = Ash.ActionInput.get_argument(input, :ticket_id)

    case Tutorial.Support.get_ticket_by_id(ticket_id, scope: context) do
      {:ok, %{status: :open}} -> :ok
      {:ok, _} -> {:error, field: :ticket_id, message: "must refer to an open ticket"}
      {:error, error} -> {:error, error}
    end
  end
end

# usage
validate TicketOpen
validate MatchesCustomer, only_when_valid?: true   # skip if already invalid
```

`scope: context` passes the caller's actor, tenant, and authorize settings on to the nested call. `Ash.Context.to_opts(context)` does the same and returns a keyword list.

# Custom preparations

A preparation is the read-side version of a change. It modifies a query, or the input of a generic action.

```elixir
defmodule Tutorial.Support.Preparations.RejectClosedTickets do
  use Ash.Resource.Preparation

  @impl true
  def supports(_opts), do: [Ash.ActionInput]

  @impl true
  def prepare(input, _opts, context) do
    case Tutorial.Support.list_tickets(:closed, actor: context.actor, page: false) do
      {:ok, closed} ->
        closed_ids = MapSet.new(closed, & &1.id)

        Ash.ActionInput.set_argument(input, :ticket_ids,
          Enum.reject(input.arguments.ticket_ids, &MapSet.member?(closed_ids, &1)))

      {:error, error} ->
        Ash.ActionInput.add_error(input, error)
    end
  end
end
```

On a read action: `prepare build(sort: [created_at: :desc])` or `prepare MyPreparation`.

# Calculations, advanced

## Expression calculations through relationships

They run in SQL, so you can filter and sort on them.

```elixir
calculations do
  calculate :representative_name, :string, expr(representative.name), public?: true

  calculate :last_comment, :string,
    expr(first(comments, field: :body, query: [sort: [created_at: :desc]]))
end
```

## Module calculations

Use a module when the logic doesn't fit in SQL. Options passed in a tuple let one module serve many calculations.

```elixir
calculate :resolution_hours,   :integer, {ResolutionTime, unit: :hour}
calculate :resolution_minutes, :integer, {ResolutionTime, unit: :minute}
```

```elixir
defmodule Tutorial.Support.Calculations.ResolutionTime do
  use Ash.Resource.Calculation

  @impl true
  def init(opts), do: if(opts[:unit] in [:hour, :minute], do: {:ok, opts}, else: {:error, "bad unit"})

  @impl true
  def load(_query, _opts, _context), do: [:created_at, :closed_at]   # what to preload

  @impl true
  def calculate(records, opts, _context) do
    Enum.map(records, fn                                             # one value per record
      %{closed_at: nil} -> nil
      ticket -> DateTime.diff(ticket.closed_at, ticket.created_at, opts[:unit])
    end)
  end
end
```

`calculate/3` gets a **list** of records and must return a list of the same length.

# Aggregates and relationships, advanced

```elixir
aggregates do
  max :last_comment_at, :comments, :created_at
  exists :has_comments, :comments                    # boolean
end

relationships do
  has_many :comments, Comment do
    default_sort created_at: :asc
  end

  many_to_many :tags, Tag do
    through TicketTag
    source_attribute_on_join_resource :ticket_id
    destination_attribute_on_join_resource :tag_id
  end

  # relationship defined only by a filter (no FK)
  has_many :similar_tickets, __MODULE__ do
    no_attributes? true
    filter expr(subject == parent(subject) and id != parent(id))
  end
end

# on Representative: pick one record out of many
has_one :latest_open_ticket, Ticket do
  destination_attribute :representative_id
  from_many? true
  filter expr(status == :open)
  sort created_at: :desc
end
```

- `parent(field)` points at the source record inside a relationship filter.
- `exists(rel, condition)` works in any expression: `exists(comments, author_id == ^actor(:id))`.

# Identities, upserts, bulk

```elixir
identities do
  identity :unique_external_id, [:external_id]
  identity :unique_tag, [:ticket_id, :tag_id]      # composite unique index
end
```

Upsert (insert, or update on conflict):

```elixir
Tutorial.Support.import_ticket(data,
  actor: actor,
  upsert?: true,
  upsert_identity: :unique_external_id)
```

Bulk: pass a **list** to a create code interface and it becomes a bulk create.

```elixir
result =
  Tutorial.Support.import_ticket(tickets_data,
    actor: actor,
    bulk_options: [
      upsert?: true,
      upsert_identity: :unique_external_id,
      upsert_fields: [:subject, :status],   # only overwrite these on conflict
      return_records?: true,
      return_errors?: true,
      stop_on_error?: false
    ])

case result do
  %Ash.BulkResult{status: :success, records: records} -> {:ok, records}
  %Ash.BulkResult{status: :partial_success, records: records} -> {:ok, records}
  %Ash.BulkResult{status: :error, errors: errors} -> {:error, errors}
end
```

# Code interfaces, advanced

## Domain-level vs resource-level

```elixir
# domain: Tutorial.Support.get_ticket_by_id/2  (preferred: callers go through the domain)
resource Ticket do
  define :get_ticket_by_id, action: :read, get_by: [:id]
  define :list_tickets, action: :list, args: [:status]
  define :open_ticket, action: :open
end

# resource: Tutorial.Accounts.User.sign_in_with_password/2
code_interface do
  define :sign_in_with_password
end
```

## Options every interface accepts

```elixir
Tutorial.Support.get_ticket_by_id(id,
  actor: user,                                      # who is calling (policies)
  load: [:representative_name, comments: [:author]])

Tutorial.Support.list_tickets(:open, actor: user, page: false)
Tutorial.Support.list_tickets(nil, actor: user)     # positional args come first; nil = not given
Tutorial.Support.list_tickets(nil, actor: user, query: [filter: [priority: :urgent]])
Tutorial.Support.changeset_to_open_ticket(%{}, actor: user)   # build the changeset only
```

- Each interface has `name/n` returning `{:ok, _} | {:error, _}` and `name!/n` that raises.
- `default_options:` on `define` sets options for every call, for example default `bulk_options`.

# Actors

The actor is whoever performs the action. Pass it on **every** call. Policies only see what you pass.

```elixir
# controllers: AshAuthentication's plug put it on the conn
actor = Ash.PlugHelpers.get_actor(conn)
Tutorial.Support.list_tickets(nil, actor: actor)
```

Background jobs have no user. Give them a **scoped system actor** instead of `authorize?: false`.

```elixir
defmodule Tutorial.SystemActor do
  @enforce_keys [:role]
  defstruct [:role, :ticket_id]
end

actor = %Tutorial.SystemActor{role: :ticket_import}
actor = %Tutorial.SystemActor{role: :ticket_summarizer, ticket_id: ticket.id}  # only this ticket
```

**Key takeaway:** avoid `authorize?: false`. Give background work an actor whose role and ids describe exactly what it may touch.

# Policies

Policies sit on the resource (and optionally the domain) and are added with `authorizers: [Ash.Policy.Authorizer]`.

```elixir
policies do
  bypass actor_attribute_equals(:role, :admin) do   # passes → skip all other policies
    authorize_if always()
  end

  policy action_type(:read) do                      # which requests this policy applies to
    authorize_if actor_attribute_equals(:role, :manager)
    authorize_if relates_to_actor_via(:customer)
    forbid_unless actor_attribute_equals(:role, :representative)
    authorize_if expr(representative_id == ^actor(:id))
  end

  policy action([:update, :destroy]) do
    authorize_if relates_to_actor_via(:representative)
  end
end
```

How a policy is evaluated:

- Checks run top to bottom, and the **first check that decides** wins.
- `authorize_if x`: if x is true, authorized.
- `forbid_if x`: if x is true, forbidden.
- `forbid_unless x`: if x is false, forbidden. Otherwise move on to the next check.
- If no check decides, the result is forbidden.
- Every policy whose condition matches must pass. A `bypass` that passes short-circuits the rest.

## Reads filter, writes fail

On reads, filter-style checks (`expr`, `relates_to_actor_via`) become a SQL `WHERE`. Unauthorized rows simply disappear.

```elixir
assert {:ok, []} = Tutorial.Support.list_tickets(nil, actor: other_customer, page: false)
assert {:error, _} = Tutorial.Support.get_ticket_by_id(ticket.id, actor: other_customer)  # not found
assert {:error, %Ash.Error.Forbidden{}} = Tutorial.Support.close_ticket(ticket, actor: customer)
```

## Useful built-in checks

| Check | Meaning |
|---|---|
| `always()` | always true |
| `action(:name)` / `action_type(:read)` | match the current action |
| `actor_attribute_equals(:role, :admin)` | actor field equals a value |
| `relates_to_actor_via(:path)` | the record links to the actor through the path |
| `expr(owner_id == ^actor(:id))` | any expression, becomes a filter on reads |
| `changing_attributes(customer_id: [to: actor(:id)])` | create/update sets a field to a given value |
| `can_read(:ticket)` | actor may read the related record |

## Custom checks

```elixir
defmodule Tutorial.PolicyChecks.IsStaff do
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is support staff"

  @impl true
  def match?(%{role: role}, _context, _opts) when role in [:representative, :manager, :admin], do: true
  def match?(_, _context, _opts), do: false
end

# with options
bypass {SystemActorRole, roles: [:ticket_import]} do
  authorize_if always()
end
```

Checking ahead of time (to show or hide UI): `Ash.can?({Ticket, :close}, actor)`.

Custom error message: `error_message fn _subject, _context -> "Only managers can delete tickets." end` inside a policy.

# Fragments

You can split a large resource across files. A fragment holds DSL that gets merged into the resource.

```elixir
defmodule Tutorial.Support.TicketEscalation do
  use Spark.Dsl.Fragment, of: Ash.Resource, extensions: AshOban

  actions do
    update :escalate do ... end
  end

  attributes do
    attribute :escalated_at, :utc_datetime, public?: true
  end
end

# in the resource
use Ash.Resource, fragments: [Tutorial.Support.TicketEscalation]
```

# State machines (AshStateMachine)

```elixir
use Ash.Resource, extensions: [AshStateMachine]

state_machine do
  state_attribute :status              # default attribute name is :state
  initial_states [:open]
  default_initial_state :open

  transitions do
    transition :start, from: :open, to: :in_progress
    transition :close, from: [:open, :in_progress], to: :closed
    transition :reopen, from: :closed, to: :open
  end
end

update :close do
  change transition_state(:closed)     # errors if the transition is not allowed
end
```

# PubSub notifications

Ash broadcasts after a successful action. Listeners react without coupling to the resource.

```elixir
use Ash.Resource,
  extensions: [Ash.Notifier.PubSub],
  notifiers: [Ash.Notifier.PubSub]

pub_sub do
  module TutorialWeb.Endpoint
  prefix "ticket"

  publish_all :update, [:id], event: "updated"     # topic "ticket:<id>"

  publish :close, "closed" do                      # topic "ticket:closed"
    transform fn notification -> %{ticket_id: notification.data.id} end
  end

  publish :reprioritize, "escalated" do
    filter fn n -> Ash.Changeset.get_attribute(n.changeset, :priority) == :urgent end
  end
end
```

- Topic = `prefix` + route parts joined with `:`. Atoms in the route are replaced with record values.
- `transform` keeps payloads small and serialisable.
- `module` is anything with `broadcast/3`: your Endpoint, or your own wrapper around `Phoenix.PubSub`.

Listener: a GenServer started in `application.ex` that subscribes and enqueues a job.

```elixir
defmodule Tutorial.Support.Listeners.SatisfactionSurvey do
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    :ok = TutorialWeb.Endpoint.subscribe("ticket:closed")
    {:ok, %{}}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{payload: %{ticket_id: id}}, state) do
    %{ticket_id: id} |> SendSurveyWorker.new() |> Oban.insert()
    {:noreply, state}
  end
end
```

# Background jobs

## Plain Oban worker that calls the domain

```elixir
defmodule Tutorial.Support.Workers.ImportTicketsWorker do
  use Oban.Worker, queue: :imports, max_attempts: 3, unique: [period: 300]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"since" => since}}) do
    actor = %Tutorial.SystemActor{role: :ticket_import}

    with {:ok, tickets} <- ExternalHelpdesk.fetch_tickets(since),
         %Ash.BulkResult{status: :success} <-
           Tutorial.Support.import_ticket(tickets, actor: actor,
             bulk_options: [upsert?: true, upsert_identity: :unique_external_id]) do
      :ok
    else
      {:error, :rate_limited, retry_after} -> {:snooze, retry_after}
      %Ash.BulkResult{errors: errors} -> {:error, errors}   # Oban retries
      {:error, reason} -> {:error, reason}
    end
  end
end
```

Cron jobs go in config: `{Oban.Plugins.Cron, crontab: [{"0 2 * * *", ImportTicketsWorker}]}`.

## AshOban triggers

AshOban generates the scheduler and worker from DSL. It runs an action on every record matching `where`.

```elixir
oban do
  triggers do
    trigger :escalate do
      action :escalate
      read_action :escalation_candidates          # must support keyset pagination
      where expr(status == :open and created_at < ago(2, :day) and is_nil(escalated_at))
      scheduler_cron "0 * * * *"
      queue :escalations
      max_attempts 5
    end
  end
end

# AshOban runs without your actor; allow exactly its actions
policies do
  bypass AshOban.Checks.AshObanInteraction do
    authorize_if action([:escalation_candidates, :escalate])
  end
end
```

# Authentication (AshAuthentication)

The `User` resource holds `authentication do strategies ... end`. Most of the actions in it are generated or wired by the installer.

```elixir
# router
pipeline :browser do
  plug :load_from_session      # reads token from session
  plug :set_actor, :user       # conn's actor = current_user
end

pipeline :api do
  plug :load_from_bearer       # Authorization: Bearer <jwt>
  plug :set_actor, :user
end

auth_routes AuthController, Tutorial.Accounts.User, path: "/auth"
sign_out_route AuthController
```

- `AshAuthentication.Checks.AshAuthenticationInteraction` is the bypass for sign-in and token flows.
- Assign roles with an attribute (`:role` with `one_of:`) and check them in policies.

# Web layer: controllers and channels

Controllers stay thin. They call a domain function with the actor and map errors to HTTP responses.

```elixir
def create(conn, %{"ticket_id" => ticket_id, "file" => %Plug.Upload{} = upload}) do
  case Tutorial.Support.attach_file(ticket_id, upload, actor: Ash.PlugHelpers.get_actor(conn)) do
    {:ok, attachment} -> conn |> put_status(:created) |> json(%{data: %{id: attachment.id}})
    {:error, %Ash.Error.Forbidden{}} -> conn |> put_status(:forbidden) |> json(%{error: "Forbidden"})
    {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Unable to upload."})
  end
end
```

Channels authorize the join by reading through Ash with the socket's actor:

```elixir
def join("ticket:" <> id, _params, %{assigns: %{current_user: actor}} = socket) do
  case Tutorial.Support.get_ticket_by_id(id, actor: actor) do
    {:ok, ticket} -> {:ok, %{status: to_string(ticket.status)}, socket}
    {:error, reason} -> {:error, %{reason: inspect(reason)}}
  end
end
```

# AshTypescript RPC (Ash behind a React SPA)

**1. Mark the resource and expose actions in the domain**

```elixir
# resource
use Ash.Resource, extensions: [AshTypescript.Resource]
typescript do
  type_name "Ticket"
end

# domain
use Ash.Domain, extensions: [AshTypescript.Rpc]

typescript_rpc do
  resource Ticket do
    rpc_action :open_ticket, :open
    rpc_action :list_tickets, :list
    rpc_action :close_ticket, :close
  end
end
```

**2. One controller runs every action** (policies still apply, since the actor comes from the conn)

```elixir
post "/rpc/run", AshTypescriptRpcController, :run

def run(conn, params), do: json(conn, AshTypescript.Rpc.run_action(:tutorial, conn, params))
```

**3. Generate TS** with `mix ash_typescript.codegen`, which writes the file set by `output_file` in config.

**4. Call it from React** with typed `fields` (what to return) and `input` (camelCase)

```ts
const result = await openTicket({
  fields: ['id', 'subject', 'status'],
  input: { subject, description }
})
if (!result.success) throw new Error(result.errors.map((e) => e.message).join(', '))

await closeTicket({ identity: ticketId, fields: ['status'] })
```

Only `public? true` attributes, relationships, and calculations can be requested in `fields`.

# Using resources in LiveView (AshPhoenix)

## Reading data

```elixir
def mount(_params, _session, socket) do
  user = socket.assigns.current_user
  # resource: pub_sub do module TutorialWeb.Endpoint; prefix "ticket"; publish :open, "created" end
  if connected?(socket), do: TutorialWeb.Endpoint.subscribe("ticket:created")

  tickets = Tutorial.Support.list_tickets!(nil, actor: user, load: [:representative_name])
  {:ok, stream(socket, :tickets, tickets)}
end

# payload is the %Ash.Notifier.Notification{}; .data is the record
def handle_info(%Phoenix.Socket.Broadcast{payload: %{data: ticket}}, socket),
  do: {:noreply, stream_insert(socket, :tickets, ticket, at: 0)}
```

## Forms: AshPhoenix.Form wraps an action

```elixir
def mount(_params, _session, socket) do
  form =
    Tutorial.Support.Ticket
    |> AshPhoenix.Form.for_create(:open, actor: socket.assigns.current_user)
    |> to_form()

  {:ok, assign(socket, form: form)}
end

def handle_event("validate", %{"form" => params}, socket) do
  {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
end

def handle_event("save", %{"form" => params}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
    {:ok, ticket} ->
      {:noreply, socket |> put_flash(:info, "Ticket opened") |> push_navigate(to: ~p"/tickets/#{ticket.id}")}

    {:error, form} ->
      {:noreply, assign(socket, form: form)}   # errors are already on the form
  end
end
```

```heex
<.form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:subject]} label="Subject" />
  <.input field={@form[:description]} type="textarea" />
  <.button>Open</.button>
</.form>
```

- Edit form: `AshPhoenix.Form.for_update(ticket, :update, actor: user)`.
- Params arrive under `"form"` by default. Change it with `as: "ticket"`.
- Validation errors come from the action's validations and constraints, so you don't need a separate Ecto changeset.
- With `extensions: [AshPhoenix]` on the domain, each code interface also gets `form_to_<name>`, e.g. `Tutorial.Support.form_to_open_ticket(actor: user)`.

## Authenticated live routes

```elixir
ash_authentication_live_session :authenticated,
  on_mount: {TutorialWeb.LiveUserAuth, :live_user_required} do
  live "/tickets", TicketLive.Index
end
```

`LiveUserAuth` is generated by the AshAuthentication installer and puts `current_user` into assigns. Pass it as `actor:` everywhere.

# Testing

```elixir
defmodule Tutorial.Support.TicketTest do
  use Tutorial.DataCase, async: true    # SQL sandbox, rolled back after each test

  @manager %{role: :manager}            # a plain map works as an actor

  setup do
    # Ash.Seed writes directly, skipping actions and policies (fast fixtures)
    customer = Ash.Seed.seed!(User, %{email: "c@example.com", role: :customer})
    other = Ash.Seed.seed!(User, %{email: "o@example.com", role: :customer})
    ticket = Ash.Seed.seed!(Ticket, %{subject: "Broken", customer_id: customer.id})
    %{customer: customer, other: other, ticket: ticket}
  end

  test "customers only see their own tickets", %{customer: customer, other: other, ticket: ticket} do
    # go through the real code interface + actor, to exercise policies
    assert {:ok, [%{id: id}]} = Tutorial.Support.list_tickets(nil, actor: customer, page: false)
    assert id == ticket.id
    assert {:ok, []} = Tutorial.Support.list_tickets(nil, actor: other, page: false)
    assert Ash.can?({Ticket, :close}, @manager)
  end
end
```

- Seed fixtures with `Ash.Seed`, and assert through code interfaces with a real actor.
- Policy tests are the most valuable: who can read, create, and destroy what.
- Introspection: `Ash.Resource.Info.actions(Resource)`, e.g. to assert an action is `public?: false`.

# Cheat sheet

| Need | Reach for |
|---|---|
| Rename the operation, restrict inputs | custom action + `accept` |
| Input that isn't a column | `argument` |
| Set/derive a field on write | `change set_attribute(...)` or a change module |
| Side effect after write | `after_action` (in tx) / `after_transaction` (after commit) |
| Business rule | `validate` / validation module |
| Modify a read query | `filter` / `prepare build(...)` / preparation module |
| Non-CRUD operation | generic `action :name, :type` + `run` |
| Create children with parent | `manage_relationship` |
| Insert-or-update | `identity` + `upsert?: true` |
| Many records at once | list into code interface + `bulk_options` |
| Who may do what | `policies` + actor on every call |
| Background processing | Oban worker + `SystemActor`, or AshOban trigger |
| React to changes | `pub_sub` notifier + listener |
| Lifecycle states | AshStateMachine |
| Schema change | edit resource → `mix ash.codegen name` |
