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
    |> assign(:result, empty_result())
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
        |> noreply()

      {:error, error} ->
        socket
        |> put_flash(:error, "#{inspect(error)}")
        |> noreply()
    end
  end

  defp handle_response(%{columns: cols, rows: rows, num_rows: num_rows}) do
    rows =
      rows
      |> Enum.map(&Enum.zip(cols, &1))
      |> Enum.map(&Enum.into(&1, %{}))

    %{cols: cols, rows: rows, num_rows: num_rows}
  end
end
