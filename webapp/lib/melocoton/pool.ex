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
    repo.start_link(database: database.url, pool_size: 5)
    {:reply, repo, state}
  end

  def get_repo(database) do
    GenServer.call(__MODULE__, {:get_repo, database})
  end

  defp create_repo(database) do
    module_str = """
      defmodule Melocoton.Repos.#{database.name |> Macro.camelize()} do
      use Ecto.Repo,
          otp_app: :melocoton,
          adapter: Ecto.Adapters.SQLite3
      end
    """

    [{module, _bytecode}] = Code.compile_string(module_str)

    {:ok, module}
  end
end
