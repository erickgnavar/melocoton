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
        connect(database, state)

      %Connection{pid: pid} = conn ->
        if Process.alive?(pid) do
          {:reply, conn, state}
        else
          connect(database, Map.delete(state, database.id))
        end
    end
  end

  defp connect(database, state) do
    case start_connection(database) do
      {:ok, pid} ->
        conn = %Connection{pid: pid, type: database.type}
        {:reply, conn, Map.put(state, database.id, conn)}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  def get_repo(database), do: GenServer.call(__MODULE__, {:get_conn, database})

  defp start_connection(%{type: :postgres, url: url}) do
    opts = Ecto.Repo.Supervisor.parse_url(url)
    Postgrex.start_link(opts ++ [pool_size: 5, ssl_opts: [verify: :verify_none]])
  end

  defp start_connection(%{type: :mysql, url: url}) do
    uri = URI.parse(url)
    {user, password} = parse_userinfo(uri.userinfo)

    MyXQL.start_link(
      hostname: uri.host || "localhost",
      port: uri.port || 3306,
      username: user,
      password: password,
      database: String.trim_leading(uri.path || "", "/"),
      pool_size: 5,
      after_connect: fn conn -> MyXQL.query!(conn, "SET sql_mode = 'ANSI_QUOTES'", []) end
    )
  end

  defp start_connection(%{type: :sqlite, url: url}) do
    DBConnection.start_link(Exqlite.Connection, database: url, pool_size: 1)
  end

  defp parse_userinfo(nil), do: {"", ""}

  defp parse_userinfo(userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [user, pass] -> {user, pass}
      [user] -> {user, ""}
    end
  end
end
