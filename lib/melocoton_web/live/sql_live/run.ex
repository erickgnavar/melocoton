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
    |> assign(:search_form, to_form(%{"term" => ""}))
    |> assign(:search_term, "")
    |> assign(:repo, repo)
    |> assign(:tables, get_tables(repo, database.type))
    |> assign(:indexes, get_indexes(repo, database.type))
    |> assign(:database, database)
    |> assign(:current_session, current_session)
    |> assign(:result, empty_result())
    |> assign(:error_message, nil)
    |> assign(:page_title, database.name)
    |> assign(:pid, self())
    |> assign(:running_transaction?, false)
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

  def handle_event("validate-search", %{"term" => term}, socket) do
    socket
    |> assign(:search_term, term)
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
    # load query into SQL editor
    |> push_event("load-query", %{"query" => session.query})
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
    # load query into SQL editor
    |> push_event("load-query", %{"query" => session.query})
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event("run-query", %{"query" => query}, socket) do
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

  def handle_event("reload-objects", _params, socket) do
    socket
    |> assign(:tables, get_tables(socket.assigns.repo, socket.assigns.database.type))
    |> assign(:indexes, get_indexes(socket.assigns.repo, socket.assigns.database.type))
    |> noreply()
  end

  defp create_session(database) do
    {:ok, session} = Databases.create_session(%{database_id: database.id, query: ""})
    session
  end

  defp translate_query_error(%Postgrex.Error{postgres: %{message: message}}), do: message
  defp translate_query_error(%Exqlite.Error{message: message}), do: message

  defp handle_response(%{columns: cols, rows: rows, num_rows: num_rows}) do
    cols = cols || []

    rows =
      rows
      |> Kernel.||([])
      |> Enum.map(&Enum.zip(cols, normalize_value(&1)))
      |> Enum.map(&Enum.into(&1, %{}))

    %{cols: cols, rows: rows, num_rows: num_rows}
  end

  defp normalize_value(values) do
    Enum.map(values, fn
      # handle uuid columns that are returned as raw binary data
      <<raw_uuid::binary-size(16)>> ->
        case Ecto.UUID.cast(raw_uuid) do
          {:ok, casted_value} ->
            casted_value

          :error ->
            "ERROR"
        end

      value when is_map(value) ->
        Jason.encode!(value)

      value ->
        value
    end)
  end

  defp get_tables(repo, :postgres) do
    sql = """
    SELECT table_name
    FROM information_schema.tables
    WHERE table_type = 'BASE TABLE' AND table_schema NOT IN ('pg_catalog', 'information_schema');
    """

    case repo.query(sql) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(&Enum.at(&1, 0))
        |> Enum.map(fn name ->
          cols =
            case repo.query(
                   "SELECT * FROM information_schema.columns WHERE table_schema = 'public' AND table_name = '#{name}';"
                 ) do
              {:ok, result} ->
                result
                |> handle_response()
                |> Map.get(:rows)
                |> Enum.map(fn row ->
                  %{name: row["column_name"], type: row["data_type"]}
                end)

              {:error, _error} ->
                []
            end

          %{name: name, cols: cols}
        end)

      {:error, _error} ->
        []
    end
  end

  defp get_tables(repo, :sqlite) do
    sql = """
    SELECT
      name
    FROM
      sqlite_schema
    WHERE
      type = 'table' AND
      name NOT LIKE 'sqlite_%';
    """

    case repo.query(sql) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(&Enum.at(&1, 0))
        |> Enum.map(fn name ->
          cols =
            case repo.query("PRAGMA table_info(#{name});") do
              {:ok, result} ->
                result
                |> handle_response()
                |> Map.get(:rows)
                |> Enum.map(fn row ->
                  %{name: row["name"], type: row["type"]}
                end)

              {:error, _error} ->
                []
            end

          %{name: name, cols: cols}
        end)

      {:error, _error} ->
        []
    end
  end

  defp get_indexes(repo, :sqlite) do
    sql = "SELECT name, tbl_name FROM sqlite_master WHERE type = 'index';"

    case repo.query(sql) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [name, table] ->
          %{name: name, table: table}
        end)

      {:error, _error} ->
        []
    end
  end

  defp get_indexes(repo, :postgres) do
    sql = """
      SELECT
          indexname,
          tablename
      FROM pg_indexes
      WHERE schemaname = 'public'
      ORDER BY
          tablename,
          indexname;
    """

    case repo.query(sql) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [name, table] ->
          %{name: name, table: table}
        end)

      {:error, _error} ->
        []
    end
  end
end
