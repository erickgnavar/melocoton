defmodule Melocoton.Pool do
  use GenServer
  alias Melocoton.Connection

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:get_conn, database}, _from, state) do
    case Map.get(state, database.id) do
      nil ->
        case start_connection(database) do
          {:ok, pid} ->
            conn = %Connection{pid: pid, type: database.type}
            {:reply, conn, Map.put(state, database.id, conn)}

          {:error, _} = err ->
            {:reply, err, state}
        end

      conn ->
        {:reply, conn, state}
    end
  end

  def get_repo(database), do: GenServer.call(__MODULE__, {:get_conn, database})

  defp start_connection(%{type: :postgres, url: url}) do
    opts = Ecto.Repo.Supervisor.parse_url(url)
    Postgrex.start_link(opts ++ [pool_size: 5, ssl_opts: [verify: :verify_none]])
  end

  defp start_connection(%{type: :sqlite, url: url}) do
    DBConnection.start_link(Exqlite.Connection, database: url, pool_size: 5)
  end
end
