defmodule MelocotonWeb.SQLLive.Run do
  use MelocotonWeb, :live_view

  require Logger
  alias Melocoton.{Databases, Pool}

  @impl Phoenix.LiveView
  def mount(%{"database_id" => database_id}, _session, socket) do
    database = Databases.get_database!(database_id)
    repo = Pool.get_repo(database)

    socket
    |> assign(:query, "")
    |> assign(form: to_form(%{"query" => ""}))
    |> assign(:repo, repo)
    |> assign(:database, database)
    |> assign(:result, empty_result())
    |> assign(:error_message, nil)
    |> ok()
  end

  defp empty_result do
    %{cols: [], rows: [], num_rows: 0}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"query" => query}, socket) do
    socket
    |> assign(:query, query)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event("run-query", _params, socket) do
    run_query(socket)
  end

  @impl Phoenix.LiveView
  def handle_event("handle-key", %{"key" => "Enter", "metaKey" => true}, socket) do
    run_query(socket)
  end

  @impl Phoenix.LiveView
  def handle_event("handle-key", _params, socket) do
    {:noreply, socket}
  end

  defp run_query(socket) do
    Logger.info("Running query #{socket.assigns.query}")

    case socket.assigns.repo.query(socket.assigns.query, []) do
      {:ok, result} ->
        socket
        |> assign(result: handle_response(result))
        |> assign(:error_message, nil)
        |> noreply()

      {:error, error} ->
        socket
        |> assign(:error_message, "#{inspect(error)}")
        |> noreply()
    end
  end

  defp handle_response(%{columns: cols, rows: rows, num_rows: num_rows}) do
    rows =
      rows
      |> Enum.map(&Enum.zip(cols, normalize_value(&1)))
      |> Enum.map(&Enum.into(&1, %{}))

    %{cols: cols, rows: rows, num_rows: num_rows}
  end

  defp normalize_value(values) do
    Enum.map(values, fn
      # handle uuid columns that are returned as raw binary data
      value when is_binary(value) ->
        case Ecto.UUID.cast(value) do
          {:ok, casted_value} -> casted_value
          :error -> value
        end

      value ->
        value
    end)
  end
end
