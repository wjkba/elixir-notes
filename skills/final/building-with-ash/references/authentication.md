# AshAuthentication

**Versions.** As of Oct 2026, the stable releases are ash_authentication 4.x and ash_authentication_phoenix 2.x. Versions 5.0 and 3.0 are release candidates. Check `mix.lock`, and when this file and `deps/ash_authentication*/usage-rules*` disagree, follow the deps.

## Setup: use the installers, don't hand-write

```bash
mix igniter.install ash_authentication_phoenix       # pulls in ash_authentication too
mix ash_authentication.add_strategy password          # also: magic_link, api_key, github, google, oidc, ...
mix ash_authentication.add_add_on confirmation
mix ash.codegen add_authentication
```

The installers generate the User and Token resources, secrets, the router macros, `AuthController`, `LiveUserAuth` and sender stubs. Read what they generated before changing it.

## Strategies

| Strategy | Requires |
|---|---|
| `password` | `:email` (`:ci_string`) and `:hashed_password` (`sensitive? true`) attributes, an identity on email, and a reset `sender` if resettable |
| `magic_link` | an email identity, a `sender` module (`use AshAuthentication.Sender`), and tokens enabled |
| `api_key` | an ApiKey resource (hashed key, `expires_at`, `belongs_to :user`), a `valid_api_keys` relationship with `filter expr(valid)`, and a sign-in read action with `ApiKey.SignInPreparation` |
| OAuth2 (`github`, `google`, `auth0`, `apple`, `slack`, `oidc`) | secrets, tokens, a `register_with_<provider>` create action, and a **UserIdentity resource** |

## Security rules

- Never hardcode secrets. Implement `AshAuthentication.Secret` and read them from runtime config.
- Mark passwords, tokens and keys `sensitive? true`, and keep internal fields `public? false`.
- **OAuth:** match users by the provider's `(strategy, sub)` stored in UserIdentity, never by email alone.
  - `trust_email_verified?` (on by default for GitHub, Google, Auth0, Slack and Apple) controls whether a verified provider email may link to an existing account.
  - `on_untrusted_email_match` defaults to `:reject`.
  - `:confirm` needs the confirmation add-on, and the email must say which provider is being linked.
- **Every `register_with_<provider>` action** must:
  - include `change AshAuthentication.GenerateTokenChange` and `change AshAuthentication.Strategy.OAuth2.IdentityChange`;
  - take data out of the `user_info` argument in a change, never through `accept`.
- **API keys:** use a prefix (for example `prefix: :myapp`) so secret scanners can find them, always set an expiry, and restrict with policies (`user.__metadata__[:using_api_key?]`).
- Resources involved in authentication need a policy bypass: `bypass AshAuthentication.Checks.AshAuthenticationInteraction do authorize_if always() end`.

## Tokens and add-ons

```elixir
authentication do
  tokens do
    enabled? true
    token_resource MyApp.Accounts.Token
    signing_secret MyApp.Secrets
    store_all_tokens? true            # needed for log_out_everywhere
  end

  add_ons do
    confirmation :confirm do
      monitor_fields [:email]
      sender MyApp.Accounts.User.Senders.SendConfirmationEmail
    end
    log_out_everywhere do
      apply_on_password_change? true
    end
  end
end
```

## Phoenix and LiveView

- The router uses `use AshAuthentication.Phoenix.Router`. The generated `auth_routes`, `sign_in_route`, `sign_out_route` and `reset_route` handle the UI.
- **Browser pipeline:** `plug :load_from_session`. **API pipeline:** `plug :load_from_bearer` plus `plug :set_actor, :user`.
- LiveViews go inside `ash_authentication_live_session :name, on_mount: [{MyAppWeb.LiveUserAuth, :live_user_required}]`. The hooks are `:live_user_required`, `:live_user_optional` and `:live_no_user`.
- The signed-in user is in `@current_user` (AshAuthenticationPhoenix 2.x). Phoenix 1.8's own `phx.gen.auth` uses `@current_scope` instead. Check which one the project uses (its router and `LiveUserAuth`), and pass it as the `actor:`/`scope:` on every call.
- To call strategies programmatically: `AshAuthentication.Info.strategy!(User, :password) |> AshAuthentication.Strategy.action(:sign_in, params)`.
