defmodule MelocotonWeb.SQLLive.Run do
  use MelocotonWeb, :live_view

  require Logger
  alias Melocoton.{Databases, Pool, DatabaseClient}

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
    |> assign(:search_form, to_form(%{"term" => ""}))
    |> assign(:search_term, "")
    |> assign(:repo, repo)
    |> assign_async(:tables, fn -> get_tables(repo) end)
    |> assign_async(:indexes, fn -> get_indexes(repo) end)
    |> assign(:database, database)
    |> assign(:current_session, current_session)
    |> assign(:result, empty_result())
    |> assign(:error_message, nil)
    |> assign(:page_title, database.name)
    |> assign(:pid, self())
    |> assign(:running_transaction?, false)
    |> assign(:table_explorer, nil)
    |> ok()
  end

  defp empty_result do
    %{cols: [], rows: [], num_rows: 0}
  end

  @impl true
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

  def handle_event("set-table-explorer", %{"table" => table_name}, socket) do
    # we translate empty value at HTML level to nil value inside the
    # live view
    table_name = (table_name == "" && nil) || table_name

    socket
    |> assign(:table_explorer, table_name)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event("new-session", _params, socket) do
    session = create_session(socket.assigns.database)
    updated_database = Databases.get_database!(socket.assigns.database.id)

    socket
    |> assign(:database, updated_database)
    |> assign(:current_session, session)
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
    # load query into SQL editor
    |> push_event("load-query", %{"query" => session.query})
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event("run-query", %{"query" => query}, socket) do
    Logger.info("Running query #{query}")

    case DatabaseClient.query(socket.assigns.repo, query) do
      {:ok, result} ->
        socket
        |> assign(result: result)
        |> assign(:error_message, nil)
        |> noreply()

      {:error, reason} ->
        socket
        |> assign(:error_message, reason)
        |> noreply()
    end
  end

  def handle_event("reload-objects", _params, socket) do
    repo = socket.assigns.repo

    socket
    |> assign_async(:tables, fn -> get_tables(repo) end)
    |> assign_async(:indexes, fn -> get_indexes(repo) end)
    |> noreply()
  end

  @impl true
  def handle_info({MelocotonWeb.SqlLive.TableExplorerComponent, :reset_table_explorer}, socket) do
    socket
    |> assign(:table_explorer, nil)
    |> noreply()
  end

  defp create_session(database) do
    {:ok, session} = Databases.create_session(%{database_id: database.id, query: ""})
    session
  end

  defp get_tables(repo) do
    case DatabaseClient.get_tables(repo) do
      {:ok, tables} -> {:ok, %{tables: tables}}
      {:error, error} -> {:error, error}
    end
  end

  defp get_indexes(repo) do
    case DatabaseClient.get_indexes(repo) do
      {:ok, indexes} -> {:ok, %{indexes: indexes}}
      {:error, error} -> {:error, error}
    end
  end
end
