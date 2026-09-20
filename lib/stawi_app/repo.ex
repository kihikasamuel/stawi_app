defmodule StawiApp.Repo do
  use Ecto.Repo,
    otp_app: :stawi_app,
    adapter: Ecto.Adapters.Postgres
end
