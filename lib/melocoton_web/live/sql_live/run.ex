defmodule MelocotonWeb.SQLLive.Run do
  use MelocotonWeb, :live_view

  require Logger
  alias Melocoton.{Databases, Pool, DatabaseClient}

  @impl Phoenix.LiveView
  def mount(%{"database_id" => database_id}, _session, socket) do
    database = Databases.get_database!(database_id)
    repo = Pool.get_repo(database)
    # we need to get pid here because the call to get_tables/2 will be
    # made in another process so we won't be able to get the correct
    # PID
    liveview_pid = self()

    current_session =
      case database.sessions do
        [] -> create_session(database)
        [session | _rest] -> session
      end

    socket
    |> assign(:filter_results_form, to_form(%{"term" => ""}))
    |> assign(:filter_term, "")
    |> assign(:search_form, to_form(%{"term" => ""}))
    |> assign(:search_term, "")
    |> assign(:repo, repo)
    |> assign_async(:tables, fn -> get_tables(repo, liveview_pid) end)
    |> assign_async(:indexes, fn -> get_indexes(repo) end)
    |> assign(:database, database)
    |> assign(:current_session, current_session)
    |> assign(:filter_result, empty_result())
    |> assign(:result, empty_result())
    |> assign(:error_message, nil)
    |> assign(:page_title, database.name)
    |> assign(:pid, self())
    |> assign(:running_transaction?, false)
    |> assign(:table_explorer, nil)
    |> assign(:query_time, 0)
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

  def handle_event("validate-filter-results", %{"term" => ""}, socket) do
    socket
    |> assign(:filter_result, empty_result())
    |> assign(:filter_term, "")
    |> noreply()
  end

  def handle_event("validate-filter-results", %{"term" => term}, socket) do
    cols = Enum.map(socket.assigns.result.cols, &to_string/1)

    rows =
      socket.assigns.result.rows
      |> Enum.filter(fn row ->
        row
        |> Map.take(cols)
        |> Map.values()
        |> Enum.map(&to_string/1)
        |> Enum.map(&String.downcase/1)
        |> Enum.join(" ")
        |> String.contains?(String.downcase(term))
      end)

    socket
    |> assign(:filter_result, Map.put(socket.assigns.result, :rows, rows))
    |> assign(:filter_term, term)
    |> noreply()
  end

  def handle_event("next-session", _params, socket) do
    sessions = socket.assigns.database.sessions

    session_index =
      Enum.find_index(sessions, fn session ->
        session.id == socket.assigns.current_session.id
      end)

    new_session_index =
      if session_index + 1 == length(sessions) do
        0
      else
        session_index + 1
      end

    new_session = Enum.at(sessions, new_session_index)

    socket
    |> assign(:current_session, new_session)
    |> push_event("load-query", %{"query" => new_session.query})
    |> noreply()
  end

  def handle_event("prev-session", _params, socket) do
    sessions = socket.assigns.database.sessions

    session_index =
      Enum.find_index(sessions, fn session ->
        session.id == socket.assigns.current_session.id
      end)

    new_session_index =
      if session_index - 1 == -1 do
        length(sessions) - 1
      else
        session_index - 1
      end

    new_session = Enum.at(sessions, new_session_index)

    socket
    |> assign(:current_session, new_session)
    |> push_event("load-query", %{"query" => new_session.query})
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
      {:ok, result, %{total_time: total_time}} ->
        socket
        |> assign(result: result)
        |> assign(query_time: total_time)
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
    liveview_pid = self()

    socket
    |> assign_async(:tables, fn -> get_tables(repo, liveview_pid) end)
    |> assign_async(:indexes, fn -> get_indexes(repo) end)
    |> noreply()
  end

  def handle_event("do-nothing", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({MelocotonWeb.SqlLive.TableExplorerComponent, :reset_table_explorer}, socket) do
    socket
    |> assign(:table_explorer, nil)
    |> noreply()
  end

  @impl true
  def handle_info({:send_schema, schema}, socket) do
    # prepare tables information to fit
    schema_for_editor =
      schema
      |> Enum.map(fn %{name: name, cols: cols} ->
        {name, Enum.map(cols, & &1.name)}
      end)
      |> Enum.into(%{})

    socket
    |> push_event("load-schema", %{schema: schema_for_editor, type: socket.assigns.database.type})
    |> noreply()
  end

  defp create_session(database) do
    {:ok, session} = Databases.create_session(%{database_id: database.id, query: ""})
    session
  end

  # receive the liveview of the PID so we can notify once the tables
  # information is computed
  defp get_tables(repo, liveview_pid) do
    case DatabaseClient.get_tables(repo) do
      {:ok, tables} ->
        Process.send_after(liveview_pid, {:send_schema, tables}, :timer.seconds(1))
        {:ok, %{tables: tables}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_indexes(repo) do
    case DatabaseClient.get_indexes(repo) do
      {:ok, indexes} -> {:ok, %{indexes: indexes}}
      {:error, error} -> {:error, error}
    end
  end

  defp put_mark(%{value: value, term: term} = assigns) do
    match =
      value |> to_string() |> String.replace(term, "<mark>#{term}</mark>") |> Phoenix.HTML.raw()

    assigns = assign(assigns, :value, match)

    ~H"""
    {@value}
    """
  end
end
