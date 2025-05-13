defmodule Melocoton.Repo do
  use Ecto.Repo,
    otp_app: :melocoton,
    adapter: Ecto.Adapters.SQLite3
end
