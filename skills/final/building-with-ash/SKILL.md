---
name: building-with-ash
description: Builds and changes Ash Framework 3.x code — resources, domains, actions, changes, validations, code interfaces, policies, relationships, calculations, aggregates, AshPostgres migrations, AshPhoenix forms, AshAuthentication, AshOban. Use whenever the project depends on :ash (files with `use Ash.Resource` or `use Ash.Domain`) and the task adds a feature, fixes a bug, changes the data model, or writes tests touching the domain layer.
---

# Building with Ash

Ash apps are declarative: behaviour lives in resource DSL (actions, changes, validations, policies) and is called through domain code interfaces. This file lists the rules agents most often break. The references hold the patterns.

## Before writing code

1. Check versions in `mix.lock`. This skill was written against Ash 3.37, AshPostgres 2.15 and AshPhoenix 2.3. Anything marked "(3.xx+)" needs at least that Ash version.
2. Open one existing resource and its domain, and copy the project's conventions: base resource, `scope:` or `actor:`, `@current_user` or `@current_scope`, module layout.
3. If you're unsure of a DSL option or function, check a version-exact source before guessing (see [Source of truth](#source-of-truth)).

## Rules

1. **Logic lives in actions.** Write specific actions (`:publish`, `:archive`, `:register`), not a generic `:update` plus flags or helper functions in the domain. For behaviour that isn't CRUD, use a generic action (`action :name, :return_type`).
2. **Call through code interfaces.** Outside the resource (LiveViews, controllers, jobs, seeds, tests), call `MyApp.Blog.publish_post!(post, actor: user)`. Don't call `Ash.read!/Ash.update!/Ash.Changeset.*` there, and never call `Repo.*` on Ash-managed tables: that skips policies, validations and notifications.
3. **Pass actor/scope when building.** Give `actor:` or `scope:` to the code interface, or to `for_create/for_update/for_read/for_action`. Never pass it only to `Ash.create!/Ash.read!`: changes, validations and preparations run while the changeset or query is built. If the project has a scope struct implementing `Ash.Scope.ToOpts`, use `scope:` everywhere. Inside changes and hooks, the `context` argument is the scope, so pass `scope: context`.
4. **Let it crash, or handle it.** Use the `!` variants when a failure would be a bug. Match on `{:ok, _}`/`{:error, _}` only when you actually handle the error, and never write `{:ok, x} = Domain.fun(...)`.
5. **Inputs are explicit.** Actions accept nothing by default, so list `accept [...]` on each action or set `default_accept`. Attributes default to `public? false`; set `public? true` only on fields that API extensions (JSON:API, GraphQL, TypeScript RPC) must expose. Mark secrets `sensitive? true`.
6. **Stay atomic.** Update and destroy actions must be atomic by default. Before adding `require_atomic? false`, try `atomic_update/2`, `expr(...)` values, or an `atomic/3` callback. Disabling it is justified only when a hook has to read or modify the loaded record.
7. **Don't duplicate constraints.** `allow_nil? false`, `constraints` and `identities` already validate, so don't add `validate present(...)` on top of them. Express uniqueness as an `identity`; AshPostgres creates the unique index for it.
8. **In a policy, the first check that decides wins.** Consecutive `authorize_if` lines are OR. For AND, use `forbid_unless`, separate `policy` blocks, or a single `expr(a and b)`. Read actions with filter checks return fewer rows; they don't raise Forbidden.
9. **Don't hand-write migrations for Ash resources, and don't edit `priv/resource_snapshots/`.** Iterate with `mix ash.codegen --dev` and `mix ash.migrate`. When the feature is done, run `mix ash.codegen <snake_case_name>`, which squashes the dev migrations, read the generated migration, then run `mix ash.migrate`. `mix ash.codegen --check` exits non-zero when codegen is pending.
10. **`Ash.Query.filter/2` is a macro.** Run `require Ash.Query` first. Outside resource DSL, `import Ash.Expr` for `expr/1`, `^actor(:id)` and `^arg(:name)`. A "misplaced operator ^" or "undefined variable" error inside a filter means the require is missing.
11. **Prefer modules to inline functions.** Once a change, validation or preparation is longer than one line, move it into a module (`MyApp.Blog.Post.Changes.Slugify` with `use Ash.Resource.Change`).
12. **Use bulk actions instead of loops.** For many records, pass a query or a list to an update or destroy code interface, or use `Ash.bulk_create/bulk_update/bulk_destroy`. Don't `Enum.each` over single-record actions.

## Feature workflow

```
- [ ] Generate: mix ash.gen.resource MyApp.Blog.Post --extend postgres --uuid-primary-key id --timestamps --yes
      (`mix help ash.gen.resource`; add --dry-run to preview. Also: ash.gen.domain, ash.gen.change,
       ash.gen.validation, ash.gen.preparation, ash.gen.enum)
- [ ] Model: attributes → identities → relationships → named actions
- [ ] Expose: `define` code interfaces in the domain's `resources` block
- [ ] Authorize: policies (when the resource uses Ash.Policy.Authorizer)
- [ ] mix ash.codegen --dev && mix ash.migrate
- [ ] Test through the code interface
- [ ] Finish: mix ash.codegen <name> → review migration → mix ash.migrate → mix test (or mix precommit)
```

## References

Read the reference that matches the task:

| Task | File |
|---|---|
| Actions, changes, validations, preparations, hooks, atomics, generic and bulk actions, upserts, notifications, signals, errors | [references/actions.md](references/actions.md) |
| Code interfaces, read actions, filters, expressions, loading, pagination, calculations, aggregates | [references/querying.md](references/querying.md) |
| Policies, field policies, custom checks, `can_*?` helpers, debugging authorization | [references/policies.md](references/policies.md) |
| Relationships, `manage_relationship`, many-to-many, cascading | [references/relationships.md](references/relationships.md) |
| AshPostgres: foreign keys, indexes, check constraints, custom SQL, migrations, multitenancy | [references/postgres.md](references/postgres.md) |
| AshPhoenix.Form in LiveView: create, update, nested and union forms, missing errors | [references/forms.md](references/forms.md) |
| Testing: generators, policy tests, error assertions | [references/testing.md](references/testing.md) |
| AshAuthentication: strategies, tokens, add-ons, Phoenix integration | [references/authentication.md](references/authentication.md) |
| AshOban: triggers, scheduled actions, actors in jobs | [references/oban.md](references/oban.md) |

For the web layer (HEEx, LiveView lifecycle, streams), use the `building-phoenix-liveview` skill as well.

## Source of truth

When this skill and the installed version disagree, the installed version wins. Prefer these sources in order:

1. **Tidewave MCP**, if configured (`get_docs`, `project_eval`): exact versions from the running app.
2. **Rules shipped with the deps**: `deps/<pkg>/usage-rules.md` and `deps/<pkg>/usage-rules/*.md` for ash, ash_postgres, ash_phoenix, ash_oban, ash_authentication and others. They also cover topics this skill omits, such as temporal resources and AshTypescript.
3. **CLI docs**: `mix usage_rules.search_docs "term" -p ash -p ash_postgres` (when usage_rules is a dep), and `mix help <task>`.
4. **Source**: grep `deps/<pkg>/lib/` for the DSL option or function.
5. **Web**: `https://ash.hexdocs.pm/`, `https://ash-postgres.hexdocs.pm/` and so on. `hexdocs.pm/<pkg>` redirects to `<pkg-with-hyphens>.hexdocs.pm`. Fetch one module or guide page, never a whole site.
