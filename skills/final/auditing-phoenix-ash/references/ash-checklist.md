# Ash checklist

Each item: what to look for → why it matters → grep leads.

## Authorization
- **The actor is passed only at execution** (`Ash.read!(query, actor: ...)` after a `for_read` built without one) → changes and preparations don't see it.
- **`authorize?: false` outside seeds, migrations, tests and system jobs.**
- **Policies where consecutive `authorize_if` lines were meant as AND** (read the policy's intent; it's OR).
- **Resources that hold user data but have no `authorizers: [Ash.Policy.Authorizer]`.**
- **Overly broad `bypass` blocks** (anything other than admin, AshAuthentication or AshOban interaction).
- **`Ash.load!` or loads of related data without an actor** when the related resources have policies.

## Actions and logic
- **`require_atomic? false` without a hook that genuinely needs the loaded record** → rewrite with `atomic_update`, `expr`, or `atomic/3`. Leads: `require_atomic? false`.
- **External calls (HTTP, email, payment) in `before_action`/`after_action`** → hold a DB transaction. Move them to `after_transaction` or AshOban.
- **A generic `:update` driven by flags instead of named actions; logic in domain functions or helper modules instead of actions.**
- **Multi-line anonymous `fn` changes, validations or preparations** → move them into modules.
- **Validations that duplicate `allow_nil?`/`constraints`/identities.**
- **`Enum.each`/`for` loops calling single-record actions** → use bulk actions.
- **Cross-resource side effects in `after_action` hooks** → consider signals (3.36+) or notifiers.

## Data model
- **Unique business fields (email, slug) without an `identity`; upserts without `upsert_identity`.**
- **Secrets or tokens without `sensitive? true`.**
- **`belongs_to` without a matching AshPostgres `reference`** (no FK), or `on_delete: :delete` where destroy logic should run (`cascade_destroy`).
- **Attributes set to `public? true` that APIs shouldn't expose.**

## Callers
- **`Repo.*` on Ash-managed tables, or `Ash.get!/Ash.read!/Ash.Changeset.*` in web modules, jobs or seeds** → use code interfaces.
- **`{:ok, x} = Domain.fun(...)` instead of `fun!`, or ignored `{:error, _}` results.**
- **`Ash.Query.filter` without `require Ash.Query`** (compile errors that look like missing variables).

## Migrations
- **Hand-written migrations for Ash tables, or edited `priv/resource_snapshots/`.** Run `mix ash.codegen --check`.
- **Dev migrations from `mix ash.codegen --dev`** that were never squashed with a named `mix ash.codegen <name>` before merging.
