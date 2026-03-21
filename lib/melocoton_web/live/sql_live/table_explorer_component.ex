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
    |> assign(visible_columns: MapSet.new(columns), columns_dropdown_open: false)
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
      when tab in ["structure", "indexes", "relations"] do
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

  @impl true
  def handle_event("toggle-columns-dropdown", _params, socket) do
    socket
    |> assign(columns_dropdown_open: !socket.assigns.columns_dropdown_open)
    |> noreply()
  end

  @impl true
  def handle_event("close-columns-dropdown", _params, socket) do
    socket
    |> assign(columns_dropdown_open: false)
    |> noreply()
  end

  @impl true
  def handle_event("toggle-column", %{"column" => column}, socket) do
    visible = socket.assigns.visible_columns

    visible =
      if MapSet.member?(visible, column) and MapSet.size(visible) > 1 do
        MapSet.delete(visible, column)
      else
        MapSet.put(visible, column)
      end

    socket
    |> assign(visible_columns: visible)
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

  defp relation_graph(assigns) do
    %{table_name: table_name, foreign_keys: fks, referenced_by: refs, color: color} = assigns

    # Deduplicate table names
    outgoing_tables = fks |> Enum.map(& &1.foreign_table) |> Enum.uniq()
    incoming_tables = refs |> Enum.map(& &1.foreign_table) |> Enum.uniq()

    # Layout: incoming on left, current in center, outgoing on right
    left_count = length(incoming_tables)
    right_count = length(outgoing_tables)
    max_side = max(left_count, right_count)
    height = max(max_side * 50 + 40, 120)
    center_y = height / 2

    # Current table box (center)
    center_x = 250
    box_w = 120
    box_h = 30

    # Build nodes: left side (incoming)
    left_nodes =
      incoming_tables
      |> Enum.with_index()
      |> Enum.map(fn {name, i} ->
        y = spacing_y(i, left_count, height)
        %{name: name, x: 50, y: y, side: :left}
      end)

    # Build nodes: right side (outgoing)
    right_nodes =
      outgoing_tables
      |> Enum.with_index()
      |> Enum.map(fn {name, i} ->
        y = spacing_y(i, right_count, height)
        %{name: name, x: 450, y: y, side: :right}
      end)

    assigns =
      assign(assigns,
        left_nodes: left_nodes,
        right_nodes: right_nodes,
        center_x: center_x,
        center_y: center_y,
        box_w: box_w,
        box_h: box_h,
        height: height,
        color: color,
        table_name: table_name
      )

    ~H"""
    <svg
      viewBox={"0 0 620 #{@height}"}
      class="w-full"
      style={"max-height: #{max(@height, 120)}px;"}
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <marker id="arrow-out" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
          <path d="M0,0 L8,3 L0,6" fill={@color} />
        </marker>
        <marker id="arrow-in" markerWidth="8" markerHeight="6" refX="0" refY="3" orient="auto">
          <path d="M8,0 L0,3 L8,6" fill="var(--text-tertiary)" />
        </marker>
      </defs>
      <%!-- Incoming arrows (left → center) --%>
      <line
        :for={node <- @left_nodes}
        x1={node.x + @box_w / 2 + 60}
        y1={node.y}
        x2={@center_x - @box_w / 2 - 8}
        y2={@center_y}
        stroke="var(--text-tertiary)"
        stroke-width="1.5"
        stroke-dasharray="4,3"
        marker-end="url(#arrow-in)"
      />
      <%!-- Outgoing arrows (center → right) --%>
      <line
        :for={node <- @right_nodes}
        x1={@center_x + @box_w / 2}
        y1={@center_y}
        x2={node.x - @box_w / 2 + 60 - 8}
        y2={node.y}
        stroke={@color}
        stroke-width="1.5"
        marker-end="url(#arrow-out)"
      />
      <%!-- Left table boxes (incoming) --%>
      <g :for={node <- @left_nodes}>
        <rect
          x={node.x}
          y={node.y - @box_h / 2}
          width={@box_w}
          height={@box_h}
          rx="4"
          fill="var(--bg-secondary)"
          stroke="var(--border-medium)"
          stroke-width="1"
        />
        <text
          x={node.x + @box_w / 2}
          y={node.y + 4}
          text-anchor="middle"
          fill="var(--text-secondary)"
          font-size="11"
        >
          {node.name}
        </text>
      </g>
      <%!-- Center table box --%>
      <rect
        x={@center_x - @box_w / 2}
        y={@center_y - @box_h / 2}
        width={@box_w}
        height={@box_h}
        rx="4"
        fill={@color <> "22"}
        stroke={@color}
        stroke-width="2"
      />
      <text
        x={@center_x}
        y={@center_y + 4}
        text-anchor="middle"
        fill={@color}
        font-size="11"
        font-weight="600"
      >
        {@table_name}
      </text>
      <%!-- Right table boxes (outgoing) --%>
      <g :for={node <- @right_nodes}>
        <rect
          x={node.x}
          y={node.y - @box_h / 2}
          width={@box_w}
          height={@box_h}
          rx="4"
          fill="var(--bg-secondary)"
          stroke="var(--border-medium)"
          stroke-width="1"
        />
        <text
          x={node.x + @box_w / 2}
          y={node.y + 4}
          text-anchor="middle"
          fill="var(--text-secondary)"
          font-size="11"
        >
          {node.name}
        </text>
      </g>
    </svg>
    """
  end

  defp spacing_y(index, count, height) do
    if count == 1 do
      height / 2
    else
      padding = 30
      usable = height - padding * 2
      padding + index * (usable / (count - 1))
    end
  end

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
