defmodule MelocotonWeb.SQLLive.Run do
  use MelocotonWeb, :live_view

  require Logger
  alias Melocoton.{Databases, Pool}

  @impl Phoenix.LiveView
  def mount(%{"database_id" => database_id}, _session, socket) do
    database = Databases.get_database!(database_id)
    repo = Pool.get_repo(database)

    current_session =
      case database.sessions do
        [] -> create_session(database)
        [session | _rest] -> session
      end

    socket
    |> assign(:form, to_form(Databases.change_session(current_session, %{})))
    |> assign(:repo, repo)
    |> assign(:database, database)
    |> assign(:current_session, current_session)
    |> assign(:result, empty_result())
    |> assign(:error_message, nil)
    |> ok()
  end

  defp empty_result do
    %{cols: [], rows: [], num_rows: 0}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"session" => params}, socket) do
    {:ok, updated_session} = Databases.update_session(socket.assigns.current_session, params)

    socket
    |> assign(:current_session, updated_session)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event("new-session", _params, socket) do
    session = create_session(socket.assigns.database)
    updated_database = Databases.get_database!(socket.assigns.database.id)

    socket
    |> assign(:database, updated_database)
    |> assign(:current_session, session)
    |> assign(:form, to_form(Databases.change_session(session, %{})))
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event("change-session", %{"session-id" => session_id}, socket) do
    session =
      Enum.find(socket.assigns.database.sessions, fn session ->
        to_string(session.id) == session_id
      end)

    socket
    |> assign(:current_session, session)
    |> assign(:form, to_form(Databases.change_session(session, %{})))
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

  defp create_session(database) do
    {:ok, session} = Databases.create_session(%{database_id: database.id, query: ""})
    session
  end

  defp run_query(socket) do
    query = socket.assigns.current_session.query
    Logger.info("Running query #{query}")

    case socket.assigns.repo.query(query, []) do
      {:ok, result} ->
        socket
        |> assign(result: handle_response(result))
        |> assign(:error_message, nil)
        |> noreply()

      {:error, error} ->
        socket
        |> assign(:error_message, translate_query_error(error))
        |> noreply()
    end
  end

  defp translate_query_error(%Postgrex.Error{postgres: %{message: message}}), do: message
  defp translate_query_error(%Exqlite.Error{message: message}), do: message

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
