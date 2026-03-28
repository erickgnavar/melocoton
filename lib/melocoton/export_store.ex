defmodule Melocoton.ExportStore do
  @moduledoc """
  Temporary store for export data. Stores query results keyed by
  a random token so the export controller can serve downloads
  without probing LiveView process state.

  Tokens are single-use — deleted after the first read.
  """

  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Stores a result and returns a token."
  def put(result) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
    GenServer.call(__MODULE__, {:put, token, result})
  end

  @doc "Retrieves and deletes the result for a token."
  def pop(token), do: GenServer.call(__MODULE__, {:pop, token})

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:put, token, result}, _from, state) do
    {:reply, token, Map.put(state, token, result)}
  end

  @impl true
  def handle_call({:pop, token}, _from, state) do
    {result, state} = Map.pop(state, token)
    {:reply, result, state}
  end
end
