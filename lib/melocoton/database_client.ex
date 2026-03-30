defmodule Melocoton.DatabaseClient do
  @moduledoc """
  Get information about a database repository
  """

  alias Melocoton.Connection

  def query(%Connection{} = conn, sql, column_types \\ %{}) do
    init_time = System.monotonic_time(:nanosecond)
    result = Connection.query(conn, sql)
    end_time = System.monotonic_time(:nanosecond)
    total_time = System.convert_time_unit(end_time - init_time, :nanosecond, :millisecond)

    case result do
      {:ok, result} ->
        {:ok, handle_response(result, column_types), %{total_time: total_time}}

      {:error, error} ->
        {:error, translate_query_error(error)}
    end
  end

  # TODO: make specific structs for each database object
  @spec get_tables(Connection.t()) :: {:ok, [map]} | {:error, String.t()}
  def get_tables(%Connection{type: type} = conn), do: do_get_tables(conn, type)

  @spec get_indexes(Connection.t()) :: {:ok, [map]} | {:error, String.t()}
  def get_indexes(%Connection{type: type} = conn), do: do_get_indexes(conn, type)

  @spec get_table_meta(Connection.t(), String.t()) :: Melocoton.Engines.TableMeta.t()
  def get_table_meta(%Connection{type: type} = conn, table_name),
    do: do_get_table_meta(conn, table_name, type)

  @spec get_table_structure(Connection.t(), String.t()) ::
          {:ok, Melocoton.Engines.TableStructure.t()} | {:error, String.t()}
  def get_table_structure(%Connection{type: type} = conn, table_name),
    do: do_get_table_structure(conn, table_name, type)

  @spec get_estimated_count(Connection.t(), String.t()) :: non_neg_integer()
  def get_estimated_count(%Connection{type: type} = conn, table_name),
    do: do_get_estimated_count(conn, table_name, type)

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

  defp do_get_tables(conn, :postgres), do: Melocoton.Engines.Postgres.get_tables(conn)
  defp do_get_tables(conn, :mysql), do: Melocoton.Engines.Mysql.get_tables(conn)
  defp do_get_tables(conn, :sqlite), do: Melocoton.Engines.Sqlite.get_tables(conn)

  defp do_get_indexes(conn, :postgres), do: Melocoton.Engines.Postgres.get_indexes(conn)
  defp do_get_indexes(conn, :mysql), do: Melocoton.Engines.Mysql.get_indexes(conn)
  defp do_get_indexes(conn, :sqlite), do: Melocoton.Engines.Sqlite.get_indexes(conn)

  defp do_get_table_meta(conn, table_name, :postgres),
    do: Melocoton.Engines.Postgres.get_table_meta(conn, table_name)

  defp do_get_table_meta(conn, table_name, :mysql),
    do: Melocoton.Engines.Mysql.get_table_meta(conn, table_name)

  defp do_get_table_meta(conn, table_name, :sqlite),
    do: Melocoton.Engines.Sqlite.get_table_meta(conn, table_name)

  defp do_get_estimated_count(conn, table_name, :postgres),
    do: Melocoton.Engines.Postgres.get_estimated_count(conn, table_name)

  defp do_get_estimated_count(conn, table_name, :mysql),
    do: Melocoton.Engines.Mysql.get_estimated_count(conn, table_name)

  defp do_get_estimated_count(conn, table_name, :sqlite),
    do: Melocoton.Engines.Sqlite.get_estimated_count(conn, table_name)

  defp do_get_table_structure(conn, table_name, :postgres),
    do: Melocoton.Engines.Postgres.get_table_structure(conn, table_name)

  defp do_get_table_structure(conn, table_name, :mysql),
    do: Melocoton.Engines.Mysql.get_table_structure(conn, table_name)

  defp do_get_table_structure(conn, table_name, :sqlite),
    do: Melocoton.Engines.Sqlite.get_table_structure(conn, table_name)

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

  # JSON/JSONB columns: encode maps to JSON strings
  defp normalize_value(value, type) when is_map(value) and type in ["json", "jsonb"] do
    Jason.encode!(value)
  end

  # Generic map (no column type info): still encode as JSON
  defp normalize_value(value, _type) when is_map(value) do
    Jason.encode!(value)
  end

  # Binary values: show as hex unless valid UTF-8
  defp normalize_value(value, _type) when is_binary(value) do
    if String.valid?(value), do: value, else: format_binary(value)
  end

  defp normalize_value(value, _type), do: value

  defp format_binary(bin) do
    "\\x" <> Base.encode16(bin, case: :lower)
  end
end
