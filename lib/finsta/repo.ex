defmodule Finsta.Repo do
  use Ecto.Repo,
    otp_app: :finsta,
    adapter: Ecto.Adapters.SQLite3
end
