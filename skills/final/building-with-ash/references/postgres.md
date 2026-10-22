# AshPostgres

## Resource configuration

```elixir
use Ash.Resource, domain: MyApp.Blog, data_layer: AshPostgres.DataLayer

postgres do
  table "comments"
  repo MyApp.Repo

  references do
    reference :post, on_delete: :delete, index?: true
    reference :author, on_delete: :nilify
  end

  custom_indexes do
    index [:status, :inserted_at]
    index [:email], unique: true, where: "deleted_at IS NULL"
    index ["to_tsvector('english', body)"], using: "GIN", name: "comments_body_search_index"
  end

  # check_constraint attribute(s), "constraint_name", opts
  check_constraints do
    check_constraint :rating, "rating_in_range", check: "rating BETWEEN 1 AND 5", message: "must be 1-5"
  end

  custom_statements do
    statement :comments_body_trgm do
      up "CREATE INDEX comments_body_trgm ON comments USING GIN (body gin_trgm_ops);"
      down "DROP INDEX comments_body_trgm;"
    end
  end
end
```

- **Identities** (`identities do identity :unique_email, [:email] end`) produce unique indexes automatically, so don't repeat them in `custom_indexes`.
- **`on_delete`/`on_update` actions:** `:delete`, `:nilify`, `{:nilify, columns}` (PG 15+), `:restrict`, `:nothing`. They run in the DB and skip all Ash logic. When Ash logic must run, use `cascade_destroy` (see relationships.md).
- **Postgres extensions** go in the repo, not in custom statements: `def installed_extensions, do: ["ash-functions", "citext", "pg_trgm"]`. `mix ash.codegen` then generates the extension migrations.
- **Read replicas:** `repo fn _resource, type -> if type == :read, do: MyApp.ReadRepo, else: MyApp.Repo end`.

> The upstream usage-rules examples write `check_constraint :name, check: ...` without a constraint name, and `statement "SQL"` without `up`/`down`. Both are wrong; the DSL takes `check_constraint attribute, name, opts` and `statement :name do up ...; down ... end`.

## Migrations

| Situation | Command |
|---|---|
| Iterating on a feature | `mix ash.codegen --dev` → `mix ash.migrate` (repeat) |
| Feature done | `mix ash.codegen add_post_ratings` (rolls back and squashes the dev migrations) → review the file → `mix ash.migrate` |
| Preview only | `mix ash.codegen --dry-run` |
| CI or precommit guard | `mix ash.codegen --check` |
| Undo the last migration | `mix ash.rollback` |
| Reset the dev DB | `mix ash.reset` |
| Resource removed from the domain | `mix ash.codegen remove_<thing>` (drops the table and its snapshot) |
| Generate resources from an existing DB | `mix ash_postgres.gen.resources MyApp.Domain --tables ...` |

- Always read generated migrations before running them. Renames show up as drop plus add; rewrite them by hand to `rename` if you need to keep the data.
- Never edit `priv/resource_snapshots/`. Commit the snapshots together with the migrations.
- For data backfills, write a separate hand-written Ecto migration, or run an Ash bulk action from a release task.

## Multitenancy

| Strategy | When | Setup |
|---|---|---|
| `:attribute` | shared tables with an `org_id` column (the common default) | `multitenancy do strategy :attribute; attribute :organization_id end` |
| `:context` | one Postgres schema per tenant | `strategy :context`, the repo's `all_tenants/0`, and `manage_tenant` on the tenant resource; tenant migrations live in `priv/repo/tenant_migrations` and run with `mix ash_postgres.migrate --tenants` |

- Pass the tenant on every call with `tenant:`, or through the scope (`get_tenant/1`). If you forget it on a multitenant resource, the call raises an error.
- Use `global? true` in the `multitenancy` block for resources that can also be read without a tenant.
