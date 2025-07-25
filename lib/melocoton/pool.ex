defmodule Melocoton.Pool do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get_repo, database}, _from, state) do
    {:ok, repo} =
      case Map.get(state, database.id) do
        nil -> create_repo(database)
        repo -> {:ok, repo}
      end

    # TODO: eval this and return an error in case url is wrong
    case database.type do
      :sqlite ->
        repo.start_link(database: database.url, pool_size: 5)

      :postgres ->
        repo.start_link(url: database.url, pool_size: 5, ssl_opts: [verify: :verify_none])
    end

    {:reply, repo, state}
  end

  def get_repo(database) do
    GenServer.call(__MODULE__, {:get_repo, database})
  end

  defp create_repo(database) do
    adapter =
      case database.type do
        :sqlite -> "Ecto.Adapters.SQLite3"
        :postgres -> "Ecto.Adapters.Postgres"
      end

    # we need to replace spaces because elixir modules can't have
    # spaces in their name
    module_name_str =
      database.name
      |> String.trim()
      |> String.replace(" ", "_")
      |> String.replace("-", "_")
      |> Macro.camelize()

    module_name = Module.concat(Melocoton.Repos, module_name_str)

    # check if already loaded so we avoid a warning about runtime code
    # reloaded
    if Code.ensure_loaded?(module_name) do
      {:ok, module_name}
    else
      module_str = """
        defmodule #{module_name} do
        use Ecto.Repo,
            otp_app: :melocoton,
            adapter: #{adapter}
        end
      """

      [{module, _bytecode}] = Code.compile_string(module_str)

      {:ok, module}
    end
  end
end
