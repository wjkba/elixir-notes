# AshOban

AshOban turns resource actions into Oban jobs. **Triggers** run an action for every record that matches a condition. **Scheduled actions** run an action on a cron schedule.

Install with `mix igniter.install ash_oban`, which also sets up Oban. Then add `extensions: [AshOban]` to the resource.

## Triggers

```elixir
oban do
  triggers do
    trigger :send_reminder do
      action :send_reminder                     # update/destroy/generic action run per record
      where expr(status == :pending and reminder_sent_at < ago(1, :day))
      scheduler_cron "*/10 * * * *"
      queue :reminders
      max_attempts 3
      on_error :mark_reminder_failed            # update action called after the last failed attempt
      worker_module_name MyApp.Orders.Order.AshOban.Worker.SendReminder
      scheduler_module_name MyApp.Orders.Order.AshOban.Scheduler.SendReminder
    end
  end
end
```

- **Always set `worker_module_name` and `scheduler_module_name`.** Queued jobs store the module name, so renaming the resource would orphan them. `mix ash_oban.set_default_module_names` fills both in.
- The `where` filter is checked again when the job runs, so make the action change state to stop the trigger matching (or use `trigger_once?`).
- The read action used by the scheduler must support keyset pagination. Set `read_action` and `worker_read_action` if the primary read action doesn't.
- Jobs must be idempotent, because they get retried.
- `scheduler_cron` defaults to every minute. Set it to `false` to fire the trigger only manually.

## Firing jobs from code

```elixir
update :submit do
  change run_oban_trigger(:send_reminder)     # enqueue after this action succeeds
end

AshOban.run_trigger(record, :send_reminder, actor: user)
AshOban.schedule(MyApp.Orders.Order, :send_reminder)
```

## Scheduled actions

```elixir
oban do
  scheduled_actions do
    schedule :daily_digest, "0 7 * * *" do
      action :send_daily_digest                 # generic or create action
      worker_module_name MyApp.Reports.AshOban.Worker.DailyDigest
    end
  end
end
```

## Actors, policies and tenants

- To keep the actor that enqueued a job, set `config :ash_oban, :actor_persister, MyApp.ObanActorPersister`. The module implements `store/1`, which turns the actor into JSON, and `lookup/1`, which turns it back into an actor.
- When jobs run without an actor, add a policy bypass: `bypass AshOban.Checks.AshObanInteraction do authorize_if always() end`.
- For multitenancy, use `list_tenants [..]` or a function in the `oban` block, overridable per trigger.

## Snoozing, cancelling and debugging

- From inside the action, add an error to change what the job does: `AshOban.Errors.SnoozeJob.exception(snooze_for: 60)` retries later without using up an attempt, and `AshOban.Errors.CancelJob.exception(reason: :invalid)` stops the job.
- To debug, set `debug? true` on a trigger, or `config :ash_oban, :debug_all_triggers?, true` for all of them. `log_errors?` and `log_final_error?` control error logging.
- In tests, `AshOban.schedule_and_run_triggers(MyApp.Orders)` runs everything synchronously.
