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
      :sqlite -> repo.start_link(database: database.url, pool_size: 5)
      :postgres -> repo.start_link(url: database.url, pool_size: 5)
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

    module_str = """
      defmodule Melocoton.Repos.#{database.name |> Macro.camelize()} do
      use Ecto.Repo,
          otp_app: :melocoton,
          adapter: #{adapter}
      end
    """

    [{module, _bytecode}] = Code.compile_string(module_str)

    {:ok, module}
  end
end
