defmodule MelocotonWeb.SqlLive.TableExplorerComponent do
  use MelocotonWeb, :live_component
  alias Melocoton.DatabaseClient
  import Melocoton.Connection, only: [quote_identifier: 1]

  @initial_limit 20

  @impl true
  def update(%{repo: repo, table_name: table_name, database: database} = assigns, socket) do
    page = 1
    pages = 1..get_num_pages(repo, table_name, database.type, @initial_limit)

    columns = get_column_names(repo, table_name, database.type)

    socket
    |> assign(assigns)
    |> assign(active_tab: "data")
    |> assign(limit: @initial_limit, page: page, pages: Enum.to_list(pages))
    |> assign(sort_column: nil, sort_direction: nil, filter: "", columns: columns)
    |> assign(:limit_form, to_form(%{"limit" => @initial_limit}))
    |> load_data()
    |> ok()
  end

  @impl true
  def handle_event("go-back", _params, socket) do
    notify_parent(:reset_table_explorer)
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch-tab", %{"tab" => "data"}, socket) do
    socket
    |> assign(active_tab: "data")
    |> load_data()
    |> noreply()
  end

  @impl true
  def handle_event("switch-tab", %{"tab" => tab}, socket)
      when tab in ["structure", "indexes"] do
    socket
    |> assign(active_tab: tab)
    |> load_structure()
    |> noreply()
  end

  @impl true
  def handle_event("sort-column", %{"column" => column}, socket) do
    %{sort_column: current_col, sort_direction: current_dir} = socket.assigns

    {new_col, new_dir} =
      case {current_col, current_dir} do
        {^column, :asc} -> {column, :desc}
        {^column, :desc} -> {nil, nil}
        _ -> {column, :asc}
      end

    socket
    |> assign(sort_column: new_col, sort_direction: new_dir)
    |> load_data()
    |> noreply()
  end

  @impl true
  def handle_event("previous-page", _params, socket) do
    page = max(socket.assigns.page - 1, 1)

    socket
    |> assign(page: page)
    |> load_data()
    |> noreply()
  end

  @impl true
  def handle_event("next-page", _params, socket) do
    page = min(socket.assigns.page + 1, length(socket.assigns.pages))

    socket
    |> assign(page: page)
    |> load_data()
    |> noreply()
  end

  @impl true
  def handle_event("change-page", %{"page" => page}, socket) do
    {page, _} = Integer.parse(page)

    socket
    |> assign(page: page)
    |> load_data()
    |> noreply()
  end

  @impl true
  def handle_event("validate-limit", %{"limit" => limit}, socket) do
    {limit, _} = Integer.parse(limit)

    socket
    |> assign(limit: limit)
    |> load_data()
    |> noreply()
  end

  @impl true
  def handle_event("filter-rows", %{"filter" => filter}, socket) do
    socket
    |> assign(filter: filter, page: 1)
    |> load_data()
    |> noreply()
  end

  defp load_structure(socket) do
    %{repo: repo, table_name: table_name} = socket.assigns

    assign_async(socket, :structure, fn ->
      case DatabaseClient.get_table_structure(repo, table_name) do
        {:ok, structure} -> {:ok, %{structure: structure}}
        {:error, error} -> {:error, error}
      end
    end)
  end

  defp load_data(socket) do
    %{
      repo: repo,
      table_name: table_name,
      page: page,
      limit: limit,
      sort_column: sort_column,
      sort_direction: sort_direction,
      filter: filter,
      columns: columns
    } = socket.assigns

    assign_async(socket, :result, fn ->
      get_result(repo, table_name, page, limit, sort_column, sort_direction, filter, columns)
    end)
  end

  defp get_num_pages(repo, table_name, db_type, limit) do
    count = get_estimated_count(repo, table_name, db_type)
    max(div(count, limit) + 1, 1)
  end

  defp get_estimated_count(repo, table_name, :postgres) do
    sql =
      "SELECT reltuples::bigint AS count FROM pg_class WHERE relname = #{quote_identifier(table_name)}"

    case DatabaseClient.query(repo, sql) do
      {:ok, %{rows: [%{"count" => count}]}, _} when count >= 0 ->
        count

      _ ->
        # Fall back to exact count if pg_class has no stats (e.g. never analyzed)
        get_exact_count(repo, table_name)
    end
  end

  defp get_estimated_count(repo, table_name, :sqlite) do
    # sqlite_stat1 may not exist if ANALYZE has never been run, fall back to exact count
    get_exact_count(repo, table_name)
  end

  defp get_exact_count(repo, table_name) do
    case DatabaseClient.query(
           repo,
           "SELECT COUNT(*) AS count FROM #{quote_identifier(table_name)}"
         ) do
      {:ok, %{rows: [%{"count" => count}]}, _} -> count
      {:error, _error} -> 0
    end
  end

  defp get_result(repo, table_name, page, limit, sort_column, sort_direction, filter, columns) do
    offset = (page - 1) * limit
    where_clause = build_where_clause(filter, columns, repo.type)
    order_clause = build_order_clause(sort_column, sort_direction)

    sql =
      "SELECT * FROM #{quote_identifier(table_name)}#{where_clause}#{order_clause} LIMIT #{limit} OFFSET #{offset}"

    case DatabaseClient.query(repo, sql) do
      {:ok, result, _} ->
        {:ok, %{result: result}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_where_clause("", _columns, _type), do: ""
  defp build_where_clause(_filter, [], _type), do: ""

  defp build_where_clause(filter, columns, type) do
    escaped = escape_like(filter)

    conditions =
      Enum.map_join(columns, " OR ", fn col ->
        case type do
          :postgres -> "CAST(#{quote_identifier(col)} AS TEXT) ILIKE '%#{escaped}%'"
          :sqlite -> "CAST(#{quote_identifier(col)} AS TEXT) LIKE '%#{escaped}%'"
        end
      end)

    " WHERE #{conditions}"
  end

  defp escape_like(term) do
    term
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
    |> String.replace("'", "''")
  end

  defp get_column_names(repo, table_name, :sqlite) do
    case DatabaseClient.query(repo, "PRAGMA table_info(#{quote_identifier(table_name)})") do
      {:ok, %{rows: rows}, _} -> Enum.map(rows, & &1["name"])
      _ -> []
    end
  end

  defp get_column_names(repo, table_name, :postgres) do
    sql =
      "SELECT column_name FROM information_schema.columns WHERE table_name = '#{String.replace(table_name, "'", "''")}' ORDER BY ordinal_position"

    case DatabaseClient.query(repo, sql) do
      {:ok, %{rows: rows}, _} -> Enum.map(rows, & &1["column_name"])
      _ -> []
    end
  end

  defp build_order_clause(nil, _), do: ""
  defp build_order_clause(column, :asc), do: " ORDER BY #{quote_identifier(column)} ASC"
  defp build_order_clause(column, :desc), do: " ORDER BY #{quote_identifier(column)} DESC"

  defp format_column_type(col) do
    base = col["data_type"] || col["udt_name"] || ""

    cond do
      col["character_maximum_length"] ->
        "#{base}(#{col["character_maximum_length"]})"

      col["numeric_precision"] && col["numeric_scale"] ->
        "#{base}(#{col["numeric_precision"]},#{col["numeric_scale"]})"

      true ->
        base
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
