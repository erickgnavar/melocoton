defmodule MelocotonWeb.SQLLive.Run do
  use MelocotonWeb, :live_view

  require Logger
  alias Melocoton.{DatabaseClient, Databases, Pool, TransactionSession}

  @impl Phoenix.LiveView
  def mount(%{"database_id" => database_id}, _session, socket) do
    Melocoton.Settings.apply_api_keys_to_runtime()

    database = Databases.get_database!(database_id)
    conn = Pool.get_repo(database)
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
    |> assign(:conn, conn)
    |> assign_async(:tables, fn -> get_tables(conn, liveview_pid) end)
    |> assign_async(:indexes, fn -> get_indexes(conn) end)
    |> assign(:database, database)
    |> assign(:current_session, current_session)
    |> assign(:filter_result, empty_result())
    |> assign(:result, empty_result())
    |> assign(:error_message, nil)
    |> assign(:page_title, database.name)
    |> assign(:pid, self())
    |> assign(:running_transaction?, false)
    |> assign(:transaction_session, nil)
    |> assign(:table_explorer, nil)
    |> assign(:query_time, 0)
    |> assign(:ai_panel_open, false)
    |> assign(:show_settings, false)
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
        |> Enum.map_join(" ", fn v ->
          str = if is_binary(v), do: v, else: inspect(v, structs: false)
          str |> String.downcase()
        end)
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
    normalized = query |> String.trim() |> String.downcase()

    cond do
      normalized =~ ~r/^begin\b/ ->
        handle_begin(socket)

      normalized =~ ~r/^commit\b/ and socket.assigns.running_transaction? ->
        handle_commit(socket)

      normalized =~ ~r/^rollback\b/ and socket.assigns.running_transaction? ->
        handle_rollback(socket)

      socket.assigns.running_transaction? ->
        handle_transaction_query(socket, query)

      true ->
        handle_regular_query(socket, query)
    end
  end

  def handle_event("reload-objects", _params, socket) do
    conn = socket.assigns.conn
    liveview_pid = self()

    socket
    |> assign_async(:tables, fn -> get_tables(conn, liveview_pid) end)
    |> assign_async(:indexes, fn -> get_indexes(conn) end)
    |> noreply()
  end

  def handle_event("do-nothing", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle-ai-panel", _params, socket) do
    socket
    |> assign(:ai_panel_open, !socket.assigns.ai_panel_open)
    |> noreply()
  end

  @impl true
  def handle_event("open-settings", _params, socket) do
    socket
    |> assign(:show_settings, true)
    |> noreply()
  end

  @impl true
  def handle_info({MelocotonWeb.SqlLive.TableExplorerComponent, :reset_table_explorer}, socket) do
    socket
    |> assign(:table_explorer, nil)
    |> noreply()
  end

  @impl true
  def handle_info({MelocotonWeb.SqlLive.AiChatComponent, {:insert_sql, sql}}, socket) do
    socket
    |> push_event("load-query", %{query: sql})
    |> noreply()
  end

  @impl true
  def handle_info({MelocotonWeb.SqlLive.AiChatComponent, {:run_sql, sql}}, socket) do
    # Insert into editor and trigger the same flow as run-query event
    socket = push_event(socket, "load-query", %{query: sql})
    handle_event("run-query", %{"query" => sql}, socket)
  end

  @impl true
  def handle_info({MelocotonWeb.SqlLive.AiChatComponent, :close_ai_panel}, socket) do
    socket
    |> assign(:ai_panel_open, false)
    |> noreply()
  end

  @impl true
  def handle_info({MelocotonWeb.SettingsModalComponent, :close_settings}, socket) do
    socket
    |> assign(:show_settings, false)
    |> noreply()
  end

  @impl true
  def handle_info(
        {MelocotonWeb.SqlLive.AiChatComponent, {:ai_response, ref, result}},
        socket
      ) do
    send_update(MelocotonWeb.SqlLive.AiChatComponent,
      id: "ai-chat",
      ai_response: {ref, result}
    )

    noreply(socket)
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, socket)
      when pid == socket.assigns.transaction_session and not is_nil(pid) do
    socket
    |> assign(:running_transaction?, false)
    |> assign(:transaction_session, nil)
    |> noreply()
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    noreply(socket)
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

  defp handle_begin(socket) do
    case TransactionSession.start(socket.assigns.conn, self()) do
      {:ok, session_pid} ->
        Process.monitor(session_pid)

        socket
        |> assign(:running_transaction?, true)
        |> assign(:transaction_session, session_pid)
        |> assign(:error_message, nil)
        |> noreply()

      {:error, reason} ->
        socket
        |> assign(:error_message, "Failed to start transaction: #{inspect(reason)}")
        |> noreply()
    end
  end

  defp handle_commit(socket) do
    TransactionSession.commit(socket.assigns.transaction_session)

    socket
    |> assign(:running_transaction?, false)
    |> assign(:transaction_session, nil)
    |> assign(:error_message, nil)
    |> noreply()
  end

  defp handle_rollback(socket) do
    TransactionSession.rollback(socket.assigns.transaction_session)

    socket
    |> assign(:running_transaction?, false)
    |> assign(:transaction_session, nil)
    |> assign(:error_message, nil)
    |> noreply()
  end

  defp handle_transaction_query(socket, query) do
    init_time = System.monotonic_time(:nanosecond)
    result = TransactionSession.query(socket.assigns.transaction_session, query)
    end_time = System.monotonic_time(:nanosecond)
    total_time = System.convert_time_unit(end_time - init_time, :nanosecond, :millisecond)

    case result do
      {:ok, raw_result} ->
        socket
        |> assign(result: DatabaseClient.handle_response(raw_result))
        |> assign(query_time: total_time)
        |> assign(:error_message, nil)
        |> noreply()

      {:error, reason} ->
        socket
        |> assign(:error_message, DatabaseClient.translate_query_error(reason))
        |> noreply()
    end
  end

  defp handle_regular_query(socket, query) do
    case DatabaseClient.query(socket.assigns.conn, query) do
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

  defp create_session(database) do
    {:ok, session} = Databases.create_session(%{database_id: database.id, query: ""})
    session
  end

  # receive the liveview of the PID so we can notify once the tables
  # information is computed
  defp get_tables(conn, liveview_pid) do
    case DatabaseClient.get_tables(conn) do
      {:ok, tables} ->
        send(liveview_pid, {:send_schema, tables})
        {:ok, %{tables: tables}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_indexes(conn) do
    case DatabaseClient.get_indexes(conn) do
      {:ok, indexes} -> {:ok, %{indexes: indexes}}
      {:error, error} -> {:error, error}
    end
  end
end
