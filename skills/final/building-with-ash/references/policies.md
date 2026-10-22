# Policies

## Setup

```elixir
use Ash.Resource, domain: MyApp.Blog, authorizers: [Ash.Policy.Authorizer]
```

## How policies are evaluated

1. Every policy whose condition matches the action must pass.
2. Within a policy, checks run top to bottom, and **the first check that returns a decision decides**.
3. If no check decides, the policy forbids.
4. If a `bypass` passes, the remaining policies are skipped. Use bypasses for admins and system actors only.

```elixir
policies do
  bypass actor_attribute_equals(:role, :admin) do
    authorize_if always()
  end

  policy action_type(:read) do
    authorize_if expr(visibility == :public)
    authorize_if relates_to_actor_via(:author)       # OR: public, or the actor's own
  end

  policy action([:update, :publish]) do
    forbid_unless actor_attribute_equals(:active?, true) # AND: must be active...
    authorize_if relates_to_actor_via(:author)         # ...and the author
  end

  policy action_type(:create) do
    authorize_if actor_present()
  end
end
```

**Common bug:** two `authorize_if` lines written to mean AND actually mean OR. For AND, use `forbid_unless`/`forbid_if` before the final `authorize_if`, separate `policy` blocks, or a single `authorize_if expr(a and b)`.

## Checks

- **Built-in checks:** `always()`, `never()`, `actor_present()`, `actor_attribute_equals/2`, `relates_to_actor_via/1`, `relating_to_actor/1` (creates), `changing_attributes/1`, `action/1`, `action_type/1`, `expr(...)` (can use `^actor(:field)`), `accessing_from/2`.
- **Filter checks** (`expr`, `relates_to_actor_via`) on **reads** become query filters. Unauthorized rows are silently left out instead of raising `Forbidden`. On create, update and destroy, the same checks return yes or no.
- **Custom simple check** (yes/no about the actor or context):

```elixir
defmodule MyApp.Checks.ActorIsManager do
  use Ash.Policy.SimpleCheck
  def describe(_), do: "actor is a manager"
  def match?(%{role: :manager}, _context, _opts), do: true
  def match?(_, _, _), do: false
end
```

- **Custom filter check:** `use Ash.Policy.FilterCheck` and implement `filter(actor, authorizer, opts)`, which returns an `expr(...)`.

## Field policies

```elixir
field_policies do
  field_policy :salary do
    authorize_if actor_attribute_equals(:role, :hr)
  end
  field_policy :* do
    authorize_if always()
  end
end
```

A field the actor can't see comes back as `%Ash.ForbiddenField{}`. Field policies cover attributes, calculations and aggregates.

## Using authorization in code

- **In the UI:** `Blog.can_update_post?(user, post)` and `Ash.can?({post, :update}, user)` decide whether to show buttons.
- **System or admin operations** (seeds, migrations, internal jobs) pass `authorize?: false`. In web code, `authorize?: false` is a red flag.
- **AshAuthentication's own actions** need `bypass AshAuthentication.Checks.AshAuthenticationInteraction do authorize_if always() end`.

## Debugging

```elixir
# config/dev.exs or config/test.exs
config :ash, :policies, show_policy_breakdowns?: true      # breakdown in Forbidden errors
config :ash, :policies, log_policy_breakdowns: :error      # log every failed authorization
```

`mix ash.generate_policy_charts --only lib/my_app/blog/post.ex` draws a Mermaid chart of a resource's policies.
