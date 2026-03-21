defmodule Melocoton.Engines.Postgres do
  @behaviour Melocoton.Behaviours.Engine

  alias Melocoton.{Connection, DatabaseClient, Pool}
  alias Melocoton.Engines.TableStructure

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
  def get_table_structure(conn, table_name) do
    escaped = String.replace(table_name, "'", "''")

    columns_sql = """
    SELECT
      c.column_name,
      c.data_type,
      c.udt_name,
      c.is_nullable,
      c.column_default,
      c.character_maximum_length,
      c.numeric_precision,
      c.numeric_scale
    FROM information_schema.columns c
    WHERE c.table_name = '#{escaped}'
      AND c.table_schema = 'public'
    ORDER BY c.ordinal_position;
    """

    constraints_sql = """
    SELECT
      tc.constraint_name,
      tc.constraint_type,
      kcu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    WHERE tc.table_name = '#{escaped}'
      AND tc.table_schema = 'public'
    ORDER BY tc.constraint_type, tc.constraint_name, kcu.ordinal_position;
    """

    fk_sql = """
    SELECT
      tc.constraint_name,
      kcu.column_name,
      ccu.table_name AS foreign_table,
      ccu.column_name AS foreign_column
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu
      ON tc.constraint_name = ccu.constraint_name
    WHERE tc.table_name = '#{escaped}'
      AND tc.table_schema = 'public'
      AND tc.constraint_type = 'FOREIGN KEY'
    ORDER BY tc.constraint_name;
    """

    size_sql = """
    SELECT
      pg_size_pretty(pg_total_relation_size('#{escaped}'::regclass)) AS total_size,
      pg_size_pretty(pg_table_size('#{escaped}'::regclass)) AS table_size,
      pg_size_pretty(pg_indexes_size('#{escaped}'::regclass)) AS indexes_size,
      (SELECT reltuples::bigint FROM pg_class WHERE relname = '#{escaped}') AS estimated_rows
    """

    check_sql = """
    SELECT
      conname AS constraint_name,
      pg_get_constraintdef(oid) AS definition
    FROM pg_constraint
    WHERE conrelid = '#{escaped}'::regclass
      AND contype = 'c'
    ORDER BY conname;
    """

    indexes_sql = """
    SELECT
      i.relname AS index_name,
      ix.indisunique AS is_unique,
      pg_size_pretty(pg_relation_size(i.oid)) AS size,
      array_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum)) AS columns
    FROM pg_index ix
    JOIN pg_class t ON t.oid = ix.indrelid
    JOIN pg_class i ON i.oid = ix.indexrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
    WHERE t.relname = '#{escaped}'
      AND n.nspname = 'public'
    GROUP BY i.relname, ix.indisunique, i.oid
    ORDER BY i.relname;
    """

    referenced_by_sql = """
    SELECT
      tc.constraint_name,
      kcu.column_name,
      kcu.table_name AS foreign_table,
      ccu.column_name AS foreign_column
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage ccu
      ON tc.constraint_name = ccu.constraint_name
    WHERE ccu.table_name = '#{escaped}'
      AND tc.table_schema = 'public'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND kcu.table_name != '#{escaped}'
    ORDER BY kcu.table_name, tc.constraint_name;
    """

    with {:ok, columns_result} <- query_and_normalize(conn, columns_sql),
         {:ok, constraints_result} <- query_and_normalize(conn, constraints_sql),
         {:ok, fk_result} <- query_and_normalize(conn, fk_sql),
         {:ok, size_result} <- query_and_normalize(conn, size_sql),
         {:ok, check_result} <- query_and_normalize(conn, check_sql),
         {:ok, indexes_result} <- query_and_normalize(conn, indexes_sql),
         {:ok, referenced_by_result} <- query_and_normalize(conn, referenced_by_sql) do
      pk_columns =
        constraints_result.rows
        |> Enum.filter(&(&1["constraint_type"] == "PRIMARY KEY"))
        |> Enum.map(& &1["column_name"])

      unique_constraints =
        constraints_result.rows
        |> Enum.filter(&(&1["constraint_type"] == "UNIQUE"))
        |> Enum.group_by(& &1["constraint_name"])
        |> Enum.map(fn {name, rows} ->
          %{name: name, columns: Enum.map(rows, & &1["column_name"])}
        end)

      foreign_keys =
        fk_result.rows
        |> Enum.group_by(& &1["constraint_name"])
        |> Enum.map(fn {name, rows} ->
          row = hd(rows)

          %{
            name: name,
            column: row["column_name"],
            foreign_table: row["foreign_table"],
            foreign_column: row["foreign_column"]
          }
        end)

      check_constraints =
        check_result.rows
        |> Enum.map(fn row ->
          %{name: row["constraint_name"], definition: row["definition"]}
        end)

      size_info =
        case size_result.rows do
          [row | _] -> row
          _ -> %{}
        end

      indexes =
        Enum.map(indexes_result.rows, fn row ->
          %{
            name: row["index_name"],
            unique: row["is_unique"],
            columns: row["columns"],
            size: row["size"]
          }
        end)

      referenced_by =
        referenced_by_result.rows
        |> Enum.group_by(& &1["constraint_name"])
        |> Enum.map(fn {name, rows} ->
          row = hd(rows)

          %{
            name: name,
            column: row["foreign_column"],
            foreign_table: row["foreign_table"],
            foreign_column: row["column_name"]
          }
        end)

      {:ok,
       %TableStructure{
         columns: columns_result.rows,
         pk_columns: pk_columns,
         unique_constraints: unique_constraints,
         foreign_keys: foreign_keys,
         referenced_by: referenced_by,
         check_constraints: check_constraints,
         indexes: indexes,
         size: size_info
       }}
    end
  end

  defp query_and_normalize(conn, sql) do
    case Connection.query(conn, sql) do
      {:ok, result} -> {:ok, DatabaseClient.handle_response(result)}
      {:error, error} -> {:error, error}
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
