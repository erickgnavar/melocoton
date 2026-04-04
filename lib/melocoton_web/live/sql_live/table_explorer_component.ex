defmodule MelocotonWeb.SqlLive.TableExplorerComponent do
  use MelocotonWeb, :live_component
  alias Melocoton.DatabaseClient
  import Melocoton.Connection, only: [quote_identifier: 1]

  @initial_limit 20

  @impl true
  def update(%{repo: repo, table_name: table_name, database: _database} = assigns, socket) do
    page = 1
    total_count = DatabaseClient.get_estimated_count(repo, table_name)
    total_pages = max(ceil(total_count / @initial_limit), 1)

    %{columns: columns, pk_columns: pk_columns, column_types: column_types} =
      DatabaseClient.get_table_meta(repo, table_name)

    socket
    |> assign(assigns)
    |> assign(active_tab: "data")
    |> assign(
      limit: @initial_limit,
      page: page,
      total_pages: total_pages,
      total_count: total_count
    )
    |> assign(sort_column: nil, sort_direction: nil, filter: "", columns: columns)
    |> assign(pk_columns: pk_columns)
    |> assign(column_types: column_types)
    |> assign(visible_columns: MapSet.new(columns), columns_dropdown_open: false)
    |> assign(filters: [], filter_panel_open: false)
    |> assign(
      editing_cell: nil,
      pending_changes: %{},
      apply_error: nil,
      adding_row: nil,
      add_row_error: nil,
      add_row_sql_fields: MapSet.new()
    )
    |> assign(:limit_form, to_form(%{"limit" => @initial_limit}))
    |> load_data()
    |> ok()
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
    page = min(socket.assigns.page + 1, socket.assigns.total_pages)

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
  def handle_event("jump-to-page", %{"page" => page}, socket) do
    case Integer.parse(page) do
      {p, _} ->
        p = p |> max(1) |> min(socket.assigns.total_pages)

        socket
        |> assign(page: p)
        |> load_data()
        |> noreply()

      :error ->
        noreply(socket)
    end
  end

  @impl true
  def handle_event("validate-limit", %{"limit" => limit}, socket) do
    {limit, _} = Integer.parse(limit)
    total_pages = max(ceil(socket.assigns.total_count / limit), 1)
    page = min(socket.assigns.page, total_pages)

    socket
    |> assign(limit: limit, total_pages: total_pages, page: page)
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
  def handle_event("toggle-filter-panel", _params, socket) do
    opening = !socket.assigns.filter_panel_open

    filters =
      if opening and socket.assigns.filters == [] do
        [new_filter(socket.assigns.columns)]
      else
        socket.assigns.filters
      end

    socket
    |> assign(filter_panel_open: opening, filters: filters)
    |> noreply()
  end

  @impl true
  def handle_event("add-filter", _params, socket) do
    socket
    |> assign(filters: socket.assigns.filters ++ [new_filter(socket.assigns.columns)])
    |> noreply()
  end

  @impl true
  def handle_event("remove-filter", %{"id" => id}, socket) do
    filters = Enum.reject(socket.assigns.filters, &(&1.id == id))

    socket
    |> assign(filters: filters, page: 1)
    |> load_data()
    |> noreply()
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    id = params["filter_id"]

    filters =
      Enum.map(socket.assigns.filters, fn filter ->
        if filter.id == id do
          %{
            filter
            | column: params["column"] || filter.column,
              operator: params["operator"] || filter.operator,
              value: params["value"] || filter.value
          }
        else
          filter
        end
      end)

    socket
    |> assign(filters: filters, page: 1)
    |> load_data()
    |> noreply()
  end

  @impl true
  def handle_event("clear-filters", _params, socket) do
    socket
    |> assign(filters: [], filter_panel_open: false, page: 1)
    |> load_data()
    |> noreply()
  end

  @impl true
  def handle_event("toggle-filter-sql", %{"id" => id}, socket) do
    filters =
      Enum.map(socket.assigns.filters, fn filter ->
        if filter.id == id, do: %{filter | sql: !filter.sql}, else: filter
      end)

    socket
    |> assign(filters: filters, page: 1)
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

  @impl true
  def handle_event("add-row", _params, socket) do
    socket
    |> assign(adding_row: %{}, editing_cell: nil, add_row_sql_fields: MapSet.new())
    |> noreply()
  end

  @impl true
  def handle_event("cancel-add-row", _params, socket) do
    socket
    |> assign(adding_row: nil, add_row_error: nil, add_row_sql_fields: MapSet.new())
    |> noreply()
  end

  @impl true
  def handle_event("update-new-row", params, socket) do
    values = Map.take(params, socket.assigns.columns)

    socket
    |> assign(adding_row: values)
    |> noreply()
  end

  @impl true
  def handle_event("toggle-sql-field", %{"column" => col}, socket) do
    sql_fields = socket.assigns.add_row_sql_fields

    sql_fields =
      if MapSet.member?(sql_fields, col),
        do: MapSet.delete(sql_fields, col),
        else: MapSet.put(sql_fields, col)

    socket
    |> assign(add_row_sql_fields: sql_fields)
    |> noreply()
  end

  @impl true
  def handle_event("save-new-row", params, socket) do
    %{repo: repo, table_name: table_name, columns: columns, add_row_sql_fields: sql_fields} =
      socket.assigns

    values = Map.take(params, columns)

    fields =
      values
      |> Enum.filter(fn {_col, val} -> val != "" end)
      |> Enum.map(fn {col, val} -> {col, val, MapSet.member?(sql_fields, col)} end)

    case execute_insert(repo, table_name, fields) do
      :ok ->
        notify_parent({:flash, :info, "Row inserted successfully"})

        socket
        |> assign(adding_row: nil, add_row_error: nil, add_row_sql_fields: MapSet.new())
        |> load_data()
        |> noreply()

      {:error, error} ->
        socket
        |> assign(adding_row: values, add_row_error: error)
        |> noreply()
    end
  end

  @impl true
  def handle_event("edit-cell", %{"row-idx" => row_idx, "column" => column}, socket) do
    if socket.assigns.pk_columns == [] do
      noreply(socket)
    else
      {row_idx, _} = Integer.parse(row_idx)

      socket
      |> assign(editing_cell: %{row_idx: row_idx, column: column})
      |> noreply()
    end
  end

  @impl true
  def handle_event("cancel-edit", _params, socket) do
    socket
    |> assign(editing_cell: nil)
    |> noreply()
  end

  @impl true
  def handle_event("undo-cell", %{"row-idx" => row_idx, "column" => column}, socket) do
    {row_idx, _} = Integer.parse(row_idx)
    row = get_row_by_idx(socket, row_idx)

    if row do
      pk_values = pk_values_for_row(row, socket.assigns.pk_columns)
      key = {pk_values, column}

      socket
      |> assign(
        pending_changes: Map.delete(socket.assigns.pending_changes, key),
        apply_error: nil
      )
      |> noreply()
    else
      noreply(socket)
    end
  end

  @impl true
  def handle_event("save-cell", %{"value" => _value, "set-null" => "true"}, socket) do
    stage_pending_change(socket, nil)
  end

  @impl true
  def handle_event("save-cell", %{"value" => value}, socket) do
    stage_pending_change(socket, value)
  end

  @impl true
  def handle_event("apply-changes", _params, socket) do
    %{
      pending_changes: pending_changes,
      repo: repo,
      table_name: table_name,
      pk_columns: pk_columns
    } =
      socket.assigns

    case apply_changes_in_transaction(repo, table_name, pending_changes, pk_columns) do
      {:ok, :ok} ->
        socket
        |> assign(pending_changes: %{}, apply_error: nil)
        |> load_data()
        |> noreply()

      {:error, errors} ->
        socket
        |> assign(apply_error: errors)
        |> noreply()
    end
  end

  @impl true
  def handle_event("discard-changes", _params, socket) do
    socket
    |> assign(pending_changes: %{}, apply_error: nil)
    |> noreply()
  end

  @impl true
  def handle_event("dismiss-error", _params, socket) do
    socket
    |> assign(apply_error: nil)
    |> noreply()
  end

  defp stage_pending_change(socket, value) do
    case socket.assigns.editing_cell do
      nil ->
        noreply(socket)

      %{row_idx: row_idx, column: column} ->
        row = get_row_by_idx(socket, row_idx)

        if row do
          pk_values = pk_values_for_row(row, socket.assigns.pk_columns)
          key = {pk_values, column}
          original_value = Map.get(row, column)

          pending =
            if values_equal?(original_value, value) do
              Map.delete(socket.assigns.pending_changes, key)
            else
              Map.put(socket.assigns.pending_changes, key, value)
            end

          socket
          |> assign(editing_cell: nil, pending_changes: pending)
          |> noreply()
        else
          socket |> assign(editing_cell: nil) |> noreply()
        end
    end
  end

  defp values_equal?(original, new_value) do
    to_string(original || "") == to_string(new_value || "")
  end

  defp pk_values_for_row(row, pk_columns) do
    Map.new(pk_columns, fn col -> {col, Map.get(row, col)} end)
  end

  defp get_row_by_idx(socket, row_idx) do
    case socket.assigns.result do
      %{ok?: true, result: %{rows: rows}} ->
        Enum.at(rows, row_idx)

      _ ->
        nil
    end
  end

  defp cell_pending_value(pending_changes, row, pk_columns, column) do
    pk_values = pk_values_for_row(row, pk_columns)
    key = {pk_values, column}
    Map.fetch(pending_changes, key)
  end

  defp apply_changes_in_transaction(repo, table_name, pending_changes, pk_columns) do
    Melocoton.Connection.transaction(repo, fn tx_repo ->
      error =
        Enum.reduce_while(pending_changes, nil, fn {{pk_values, column}, value}, _acc ->
          case execute_update(tx_repo, table_name, pk_values, column, value, pk_columns) do
            :ok ->
              {:cont, nil}

            {:error, error} ->
              pk_desc =
                Enum.map_join(pk_values, ", ", fn {key, value} -> "#{key}=#{value}" end)

              {:halt, "#{column} (#{pk_desc}): #{error}"}
          end
        end)

      case error do
        nil -> :ok
        msg -> DBConnection.rollback(tx_repo.pid, msg)
      end
    end)
  end

  defp execute_update(repo, table_name, pk_values, column, value, pk_columns) do
    pk_where =
      Enum.map_join(pk_columns, " AND ", fn pk_col ->
        pk_val = Map.get(pk_values, pk_col)
        "#{quote_identifier(pk_col)} = '#{escape_value(pk_val)}'"
      end)

    set_clause =
      if is_nil(value) do
        "#{quote_identifier(column)} = NULL"
      else
        "#{quote_identifier(column)} = '#{escape_value(value)}'"
      end

    sql = "UPDATE #{quote_identifier(table_name)} SET #{set_clause} WHERE #{pk_where}"

    case DatabaseClient.query(repo, sql) do
      {:ok, _result, _meta} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp execute_insert(repo, table_name, []) do
    sql = "INSERT INTO #{quote_identifier(table_name)} DEFAULT VALUES"

    case DatabaseClient.query(repo, sql) do
      {:ok, _result, _meta} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp execute_insert(repo, table_name, fields) do
    cols_sql = Enum.map_join(fields, ", ", fn {col, _, _} -> quote_identifier(col) end)

    vals_sql =
      Enum.map_join(fields, ", ", fn
        {_, val, true} -> val
        {_, val, false} -> "'#{escape_value(val)}'"
      end)

    sql = "INSERT INTO #{quote_identifier(table_name)} (#{cols_sql}) VALUES (#{vals_sql})"

    case DatabaseClient.query(repo, sql) do
      {:ok, _result, _meta} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp escape_value(value) when is_binary(value), do: String.replace(value, "'", "''")
  defp escape_value(value), do: value |> to_string() |> String.replace("'", "''")

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
      filters: filters,
      columns: columns,
      column_types: column_types
    } = socket.assigns

    assign_async(socket, :result, fn ->
      get_result(repo, table_name, %{
        page: page,
        limit: limit,
        sort_column: sort_column,
        sort_direction: sort_direction,
        filter: filter,
        filters: filters,
        columns: columns,
        column_types: column_types
      })
    end)
  end

  defp visible_pages(_current, total) when total <= 7 do
    Enum.to_list(1..total)
  end

  defp visible_pages(current, total) do
    window = MapSet.new([1, total] ++ Enum.to_list(max(current - 1, 1)..min(current + 1, total)))

    1..total
    |> Enum.reduce({[], nil}, fn page, {acc, prev} ->
      if MapSet.member?(window, page) do
        {[page | acc], page}
      else
        if prev != :ellipsis, do: {[:ellipsis | acc], :ellipsis}, else: {acc, :ellipsis}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp get_result(repo, table_name, opts) do
    offset = (opts.page - 1) * opts.limit
    text_conditions = build_text_filter_conditions(opts.filter, opts.columns, repo.type)
    column_conditions = build_column_filter_conditions(opts.filters, repo.type)
    all_conditions = Enum.reject(text_conditions ++ column_conditions, &is_nil/1)

    where_clause =
      if all_conditions == [], do: "", else: " WHERE #{Enum.join(all_conditions, " AND ")}"

    order_clause = build_order_clause(opts.sort_column, opts.sort_direction)

    sql =
      "SELECT * FROM #{quote_identifier(table_name)}#{where_clause}#{order_clause} LIMIT #{opts.limit} OFFSET #{offset}"

    case DatabaseClient.query(repo, sql, opts.column_types) do
      {:ok, result, _} ->
        {:ok, %{result: result}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_text_filter_conditions("", _columns, _type), do: []
  defp build_text_filter_conditions(_filter, [], _type), do: []

  defp build_text_filter_conditions(filter, columns, type) do
    escaped = escape_like(filter)

    condition =
      Enum.map_join(columns, " OR ", fn col ->
        case type do
          :postgres -> "CAST(#{quote_identifier(col)} AS TEXT) ILIKE '%#{escaped}%'"
          :mysql -> "CAST(#{quote_identifier(col)} AS CHAR) LIKE '%#{escaped}%'"
          :sqlite -> "CAST(#{quote_identifier(col)} AS TEXT) LIKE '%#{escaped}%'"
        end
      end)

    ["(#{condition})"]
  end

  defp build_column_filter_conditions(filters, type) do
    filters
    |> Enum.reject(&(&1.value == "" and &1.operator not in ["is null", "is not null"]))
    |> Enum.map(&build_filter_condition(&1, type))
  end

  defp build_filter_condition(%{column: col, operator: "contains"} = filter, type) do
    build_contains_condition(quote_identifier(col), filter.value, filter.sql, type)
  end

  defp build_filter_condition(%{column: col, operator: op}, _type)
       when op in ["is null", "is not null"] do
    sql_op = if op == "is null", do: "IS NULL", else: "IS NOT NULL"
    "#{quote_identifier(col)} #{sql_op}"
  end

  defp build_filter_condition(%{column: col, operator: op, value: val, sql: sql}, _type) do
    quoted_col = quote_identifier(col)
    rhs = if sql, do: val, else: "'#{escape_value(val)}'"

    case op do
      "equals" -> "#{quoted_col} = #{rhs}"
      "not equals" -> "#{quoted_col} != #{rhs}"
      "greater than" -> "#{quoted_col} > #{rhs}"
      "less than" -> "#{quoted_col} < #{rhs}"
      _ -> nil
    end
  end

  defp build_contains_condition(quoted_col, val, true = _sql, type) do
    like_fn = if type == :postgres, do: "ILIKE", else: "LIKE"
    cast = if type == :mysql, do: "CHAR", else: "TEXT"
    "CAST(#{quoted_col} AS #{cast}) #{like_fn} #{val}"
  end

  defp build_contains_condition(quoted_col, val, false = _sql, type) do
    like_val = escape_like(val)
    like_fn = if type == :postgres, do: "ILIKE", else: "LIKE"
    cast = if type == :mysql, do: "CHAR", else: "TEXT"
    "CAST(#{quoted_col} AS #{cast}) #{like_fn} '%#{like_val}%'"
  end

  defp escape_like(term) do
    term
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
    |> String.replace("'", "''")
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

  defp new_filter(columns) do
    %{
      id: System.unique_integer([:positive]) |> to_string(),
      column: List.first(columns, ""),
      operator: "contains",
      value: "",
      sql: false
    }
  end

  defp active_filter_count(filters) do
    Enum.count(filters, fn f ->
      f.operator in ["is null", "is not null"] or f.value != ""
    end)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
