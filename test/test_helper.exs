case Testcontainers.start() do
  {:ok, _pid} -> ExUnit.start()
  {:error, _reason} -> ExUnit.start(exclude: [:container])
end

Ecto.Adapters.SQL.Sandbox.mode(Melocoton.Repo, :manual)
