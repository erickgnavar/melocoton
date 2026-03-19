defmodule Melocoton.Engines.Postgres do
  @behaviour Melocoton.Behaviours.Engine

  alias Melocoton.{Connection, DatabaseClient, Pool}

  @impl true
  def get_tables(conn) do
    sql = """
    SELECT t.table_name, c.column_name, c.data_type
    FROM information_schema.tables t
    LEFT JOIN information_schema.columns c
      ON c.table_schema = t.table_schema AND c.table_name = t.table_name
    WHERE t.table_type = 'BASE TABLE'
      AND t.table_schema NOT IN ('pg_catalog', 'information_schema')
    ORDER BY t.table_name, c.ordinal_position;
    """

    case Connection.query(conn, sql) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.group_by(fn [table_name | _] -> table_name end)
        |> Enum.map(fn {name, col_rows} ->
          cols =
            col_rows
            |> Enum.reject(fn [_, col_name, _] -> is_nil(col_name) end)
            |> Enum.map(fn [_, col_name, data_type] ->
              %{name: col_name, type: data_type}
            end)

          %{name: name, cols: cols}
        end)
        |> Enum.sort_by(& &1.name)
        |> then(&{:ok, &1})

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def get_indexes(conn) do
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

    case Connection.query(conn, sql) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [name, table] ->
          %{name: name, table: table}
        end)
        |> then(&{:ok, &1})

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def test_connection(database) do
    conn = Pool.get_repo(database)

    case DatabaseClient.query(conn, "SELECT 1") do
      {:ok, _result, _meta} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
