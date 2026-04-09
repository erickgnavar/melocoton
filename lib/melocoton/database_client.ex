defmodule Melocoton.DatabaseClient do
  @moduledoc """
  Get information about a database repository
  """

  alias Melocoton.Connection

  @engines %{
    postgres: Melocoton.Engines.Postgres,
    mysql: Melocoton.Engines.Mysql,
    sqlite: Melocoton.Engines.Sqlite
  }

  defp engine(type), do: Map.fetch!(@engines, type)

  def query(%Connection{} = conn, sql, column_types \\ %{}, opts \\ []) do
    init_time = System.monotonic_time(:nanosecond)
    result = Connection.query(conn, sql)
    end_time = System.monotonic_time(:nanosecond)
    total_time = System.convert_time_unit(end_time - init_time, :nanosecond, :millisecond)

    case result do
      {:ok, result} ->
        max_rows = Keyword.get(opts, :max_rows)
        {response, truncated} = maybe_truncate(handle_response(result, column_types), max_rows)
        {:ok, response, %{total_time: total_time, truncated: truncated}}

      {:error, error} ->
        {:error, translate_query_error(error)}
    end
  end

  def maybe_truncate(result, nil), do: {result, false}

  def maybe_truncate(%{rows: rows, num_rows: num_rows} = result, max_rows)
      when num_rows > max_rows do
    {%{result | rows: Enum.take(rows, max_rows), num_rows: max_rows}, true}
  end

  def maybe_truncate(result, _max_rows), do: {result, false}

  # TODO: make specific structs for each database object
  @spec get_tables(Connection.t()) :: {:ok, [map]} | {:error, String.t()}
  def get_tables(%Connection{type: type} = conn), do: engine(type).get_tables(conn)

  @spec get_indexes(Connection.t()) :: {:ok, [map]} | {:error, String.t()}
  def get_indexes(%Connection{type: type} = conn), do: engine(type).get_indexes(conn)

  @spec get_table_meta(Connection.t(), String.t()) :: Melocoton.Engines.TableMeta.t()
  def get_table_meta(%Connection{type: type} = conn, table_name),
    do: engine(type).get_table_meta(conn, table_name)

  @spec get_table_structure(Connection.t(), String.t()) ::
          {:ok, Melocoton.Engines.TableStructure.t()} | {:error, String.t()}
  def get_table_structure(%Connection{type: type} = conn, table_name),
    do: engine(type).get_table_structure(conn, table_name)

  @spec get_estimated_count(Connection.t(), String.t()) :: non_neg_integer()
  def get_estimated_count(%Connection{type: type} = conn, table_name),
    do: engine(type).get_estimated_count(conn, table_name)

  def get_all_relations(%Connection{type: type} = conn),
    do: engine(type).get_all_relations(conn)

  def test_connection_via_query(database) do
    conn = Melocoton.Pool.get_repo(database)

    case query(conn, "SELECT 1") do
      {:ok, _result, _meta} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def exact_count(conn, table_name) do
    quoted = Connection.quote_identifier(table_name)

    case query(conn, "SELECT COUNT(*) AS count FROM #{quoted}") do
      {:ok, %{rows: [%{"count" => count}]}, _} -> count
      {:error, _} -> 0
    end
  end

  def translate_query_error(%Postgrex.Error{postgres: %{message: message}}), do: message
  def translate_query_error(%MyXQL.Error{message: message}), do: message
  def translate_query_error(%Exqlite.Error{message: message}), do: message
  def translate_query_error(%DBConnection.ConnectionError{message: message}), do: message
  def translate_query_error(%Postgrex.QueryError{message: message}), do: message
  def translate_query_error(error) when is_binary(error), do: error
  def translate_query_error(error), do: inspect(error)

  def query_and_normalize(conn, sql) do
    case Connection.query(conn, sql) do
      {:ok, result} -> {:ok, handle_response(result)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Normalizes a query result into a map with `cols`, `rows`, and `num_rows`.

  Accepts an optional `column_types` map (`%{"col_name" => "type_name"}`)
  for type-aware value formatting (e.g. UUID columns decoded from raw binary).
  """
  def handle_response(result, column_types \\ %{})

  def handle_response(%{columns: cols, rows: rows, num_rows: num_rows}, column_types) do
    cols = cols || []

    rows =
      rows
      |> Kernel.||([])
      |> Enum.map(fn row ->
        cols
        |> Enum.zip(row)
        |> Enum.map(fn {col, val} ->
          {col, normalize_value(val, Map.get(column_types, col))}
        end)
        |> Enum.into(%{})
      end)

    %{cols: cols, rows: rows, num_rows: num_rows}
  end

  defp normalize_value(value, col_type)

  # UUID columns: cast raw 16-byte binary to formatted UUID string
  defp normalize_value(<<raw::binary-size(16)>>, type) when type in ["uuid", "UUID"] do
    case Ecto.UUID.cast(raw) do
      {:ok, formatted} -> formatted
      :error -> format_binary(raw)
    end
  end

  # PostgreSQL arrays: recursively normalize each element
  defp normalize_value(value, type) when is_list(value) do
    element_type = infer_array_element_type(type)
    Enum.map(value, &normalize_value(&1, element_type))
  end

  # JSON/JSONB columns: encode maps to JSON strings
  defp normalize_value(value, type) when is_map(value) and type in ["json", "jsonb"] do
    Jason.encode!(value)
  end

  # Postgrex structs (Range, Point, INET, etc.): format as readable strings.
  # Must come after JSON clause and before the generic map clause to avoid
  # crashing Jason.encode! on structs that don't implement Jason.Encoder.
  # Date/Time/NaiveDateTime/DateTime/Decimal are excluded — they pass through
  # to the display layer which renders them with type-aware formatting.
  defp normalize_value(%struct{} = value, _type)
       when struct in [
              Postgrex.Range,
              Postgrex.INET,
              Postgrex.MACADDR,
              Postgrex.Point,
              Postgrex.Interval,
              Postgrex.Lexeme,
              Postgrex.Line,
              Postgrex.LineSegment,
              Postgrex.Box,
              Postgrex.Path,
              Postgrex.Polygon,
              Postgrex.Circle,
              Postgrex.Multirange
            ] do
    format_struct(value)
  end

  # Date/Time/DateTime structs and Decimal: pass through for display-layer formatting
  defp normalize_value(%struct{} = value, _type)
       when struct in [Date, Time, NaiveDateTime, DateTime, Decimal] do
    value
  end

  # Plain maps (composite types, hstore, etc.): encode as JSON
  defp normalize_value(value, _type) when is_map(value) do
    Jason.encode!(value)
  end

  # Binary values: show as hex unless valid UTF-8
  defp normalize_value(value, _type) when is_binary(value) do
    if String.valid?(value), do: value, else: format_binary(value)
  end

  defp normalize_value(value, _type), do: value

  # Strip array suffix to get element type (e.g., "_uuid" -> "uuid", "uuid[]" -> "uuid")
  defp infer_array_element_type(nil), do: nil
  defp infer_array_element_type("_" <> element_type), do: element_type

  defp infer_array_element_type(type) do
    if String.ends_with?(type, "[]"), do: String.trim_trailing(type, "[]"), else: nil
  end

  # Format Postgrex structs into readable string representations
  defp format_struct(%Postgrex.Range{lower: lower, upper: upper} = range) do
    left = if range.lower_inclusive, do: "[", else: "("
    right = if range.upper_inclusive, do: "]", else: ")"
    lower_str = if is_nil(lower), do: "", else: to_string(lower)
    upper_str = if is_nil(upper), do: "", else: to_string(upper)
    "#{left}#{lower_str},#{upper_str}#{right}"
  end

  defp format_struct(%Postgrex.INET{address: address, netmask: netmask}) do
    ip = address |> :inet.ntoa() |> to_string()
    if netmask, do: "#{ip}/#{netmask}", else: ip
  end

  defp format_struct(%Postgrex.MACADDR{address: {a, b, c, d, e, f}}) do
    [a, b, c, d, e, f]
    |> Enum.map_join(":", &String.pad_leading(Integer.to_string(&1, 16), 2, "0"))
    |> String.downcase()
  end

  defp format_struct(%Postgrex.Point{x: x, y: y}), do: "(#{x},#{y})"

  defp format_struct(%Postgrex.Interval{months: m, days: d, secs: s, microsecs: us}) do
    parts =
      [{m, "mon"}, {d, "day"}, {s, "sec"}, {us, "usec"}]
      |> Enum.reject(fn {v, _} -> v == 0 end)
      |> Enum.map_join(" ", fn {v, unit} -> "#{v} #{unit}" end)

    if parts == "", do: "0 sec", else: parts
  end

  defp format_struct(%Postgrex.Lexeme{word: word, positions: positions}) do
    case positions || [] do
      [] -> "'#{word}'"
      pos -> "'#{word}':#{Enum.map_join(pos, ",", fn {p, _w} -> to_string(p) end)}"
    end
  end

  defp format_struct(%Postgrex.Multirange{ranges: ranges}) do
    "{" <> Enum.map_join(ranges || [], ",", &format_struct/1) <> "}"
  end

  defp format_struct(%Postgrex.Line{a: a, b: b, c: c}), do: "{#{a},#{b},#{c}}"

  defp format_struct(%Postgrex.LineSegment{point1: p1, point2: p2}) do
    "[(#{p1.x},#{p1.y}),(#{p2.x},#{p2.y})]"
  end

  defp format_struct(%Postgrex.Box{upper_right: ur, bottom_left: bl}) do
    "(#{ur.x},#{ur.y}),(#{bl.x},#{bl.y})"
  end

  defp format_struct(%Postgrex.Path{points: points, open: open}) do
    formatted = Enum.map_join(points, ",", fn p -> "(#{p.x},#{p.y})" end)
    if open, do: "[#{formatted}]", else: "(#{formatted})"
  end

  defp format_struct(%Postgrex.Polygon{vertices: vertices}) do
    "(" <> Enum.map_join(vertices, ",", fn p -> "(#{p.x},#{p.y})" end) <> ")"
  end

  defp format_struct(%Postgrex.Circle{center: c, radius: r}), do: "<(#{c.x},#{c.y}),#{r}>"

  defp format_struct(value), do: inspect(value, structs: false)

  defp format_binary(bin) do
    "\\x" <> Base.encode16(bin, case: :lower)
  end
end
