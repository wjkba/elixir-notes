defmodule Liveview.Repo do
  use Ecto.Repo,
    otp_app: :liveview,
    adapter: Ecto.Adapters.Postgres
end
