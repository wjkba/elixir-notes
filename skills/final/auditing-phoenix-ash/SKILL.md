---
name: auditing-phoenix-ash
description: Audits Phoenix LiveViews and Ash resources for memory bloat, lifecycle mistakes, authorization holes, non-atomic or misplaced logic, and deprecated APIs, then reports prioritised findings without editing code. Run manually with a file or directory path.
disable-model-invocation: true
argument-hint: "[path, default lib/]"
---

# Audit Phoenix + Ash code

Target: `$ARGUMENTS` (if empty, use `lib/`).

This audit is **read-only**. Report findings and don't edit files unless the user asks afterwards.

## Workflow

```
- [ ] 1. Inventory: list the LiveViews (*_live.ex, *_live/*.ex), components, controllers, Ash resources and domains in the target
- [ ] 2. Context: read mix.lock versions, the router (live_sessions, pipelines), and how the actor/scope is assigned
- [ ] 3. Check each LiveView and component against the LiveView checklist
- [ ] 4. Check each resource and domain against the Ash checklist (skip if the project doesn't use Ash)
- [ ] 5. Verify every candidate by reading the surrounding code. Grep hits are leads, not findings
- [ ] 6. If the project uses Ash, run `mix ash.codegen --check`. Run `mix compile --warnings-as-errors` and include real warnings
- [ ] 7. Report
```

Checklists: [references/liveview-checklist.md](references/liveview-checklist.md) and [references/ash-checklist.md](references/ash-checklist.md).

## Severity

- **High:** security (authorization bypass, IDOR, mass assignment), data loss, or unbounded memory growth.
- **Medium:** correctness or performance bugs that users will hit (double loading, N+1 queries, silent form failures, non-atomic races).
- **Low:** deprecated APIs, convention drift, maintainability.

## Report format

```markdown
## Audit: <target> (<n> files)

| # | Sev | Location | Finding | Fix |
|---|-----|----------|---------|-----|
| 1 | High | lib/app_web/live/post_live/show.ex:42 | `handle_event("delete")` loads Post by id from params without the actor | Use `Blog.get_post!(id, actor: user)` / scope-filtered lookup |

### Assigns inventory (LiveViews only)
| LiveView | Assign | Holds | Bounded? | Recommendation |

### Not checked / assumptions
- …
```

Order findings by severity, then by file. Give each finding one concrete fix. If you found nothing in an area, say so in one line instead of padding.
