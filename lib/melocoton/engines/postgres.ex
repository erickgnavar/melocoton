defmodule Melocoton.Engines.Postgres do
  @behaviour Melocoton.Behaviours.Engine

  alias Melocoton.{Connection, DatabaseClient}
  alias Melocoton.Engines.{TableMeta, TableStructure}

  @impl true
  def get_tables(conn) do
    sql = """
    SELECT t.table_name, t.table_type, c.column_name, c.data_type,
           c.is_nullable, c.column_default
    FROM information_schema.tables t
    LEFT JOIN information_schema.columns c
      ON c.table_schema = t.table_schema AND c.table_name = t.table_name
    WHERE t.table_type IN ('BASE TABLE', 'VIEW')
      AND t.table_schema NOT IN ('pg_catalog', 'information_schema')
    ORDER BY t.table_name, c.ordinal_position;
    """

    matview_sql = """
    SELECT c.relname, a.attname, format_type(a.atttypid, a.atttypmod),
           NOT a.attnotnull, pg_get_expr(d.adbin, d.adrelid)
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    LEFT JOIN pg_attribute a
      ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
    WHERE c.relkind = 'm'
      AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY c.relname, a.attnum;
    """

    with {:ok, %{rows: rows}} <- Connection.query(conn, sql),
         {:ok, %{rows: matview_rows}} <- Connection.query(conn, matview_sql) do
      tables =
        rows
        |> Enum.group_by(fn [table_name | _] -> table_name end)
        |> Enum.map(fn {name, col_rows} ->
          table_type = col_rows |> List.first() |> Enum.at(1)

          cols =
            col_rows
            |> Enum.reject(fn [_, _, col_name, _, _, _] -> is_nil(col_name) end)
            |> Enum.map(fn [_, _, col_name, data_type, is_nullable, col_default] ->
              %{
                name: col_name,
                type: data_type,
                nullable: is_nullable == "YES",
                has_default: not is_nil(col_default)
              }
            end)

          %{name: name, type: if(table_type == "VIEW", do: :view, else: :table), cols: cols}
        end)

      matviews =
        matview_rows
        |> Enum.group_by(fn [name | _] -> name end)
        |> Enum.map(fn {name, col_rows} ->
          cols =
            col_rows
            |> Enum.reject(fn [_, col_name, _, _, _] -> is_nil(col_name) end)
            |> Enum.map(fn [_, col_name, data_type, is_nullable, col_default] ->
              %{
                name: col_name,
                type: data_type,
                nullable: is_nullable,
                has_default: not is_nil(col_default)
              }
            end)

          %{name: name, type: :materialized_view, cols: cols}
        end)

      {:ok, Enum.sort_by(tables ++ matviews, & &1.name)}
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

    conn
    |> Connection.query(sql)
    |> DatabaseClient.map_rows(fn [name, table] -> %{name: name, table: table} end)
  end

  @impl true
  def get_table_meta(conn, table_name) do
    sql = """
    SELECT
      c.column_name,
      c.udt_name,
      CASE WHEN pk.column_name IS NOT NULL THEN 1 ELSE 0 END AS is_pk
    FROM information_schema.columns c
    LEFT JOIN (
      SELECT kcu.column_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
      WHERE tc.table_name = $1
        AND tc.table_schema = 'public'
        AND tc.constraint_type = 'PRIMARY KEY'
    ) pk ON pk.column_name = c.column_name
    WHERE c.table_name = $1
      AND c.table_schema = 'public'
    ORDER BY c.ordinal_position
    """

    case DatabaseClient.query_and_normalize(conn, sql, [table_name]) do
      {:ok, %{rows: []}} -> matview_meta(conn, table_name)
      {:ok, %{rows: rows}} -> rows_to_table_meta(rows)
      _ -> %TableMeta{}
    end
  end

  defp rows_to_table_meta(rows) do
    columns = Enum.map(rows, & &1["column_name"])
    column_types = Map.new(rows, fn r -> {r["column_name"], r["udt_name"]} end)

    pk_columns =
      rows
      |> Enum.filter(&(&1["is_pk"] == 1))
      |> Enum.map(& &1["column_name"])

    %TableMeta{columns: columns, pk_columns: pk_columns, column_types: column_types}
  end

  defp matview_meta(conn, table_name) do
    sql = """
    SELECT a.attname AS column_name,
           format_type(a.atttypid, a.atttypmod) AS udt_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid
    WHERE c.relname = $1::text
      AND n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND c.relkind = 'm'
      AND a.attnum > 0
      AND NOT a.attisdropped
    ORDER BY a.attnum
    """

    case DatabaseClient.query_and_normalize(conn, sql, [table_name]) do
      {:ok, %{rows: rows}} ->
        columns = Enum.map(rows, & &1["column_name"])
        column_types = Map.new(rows, fn r -> {r["column_name"], r["udt_name"]} end)
        %TableMeta{columns: columns, pk_columns: [], column_types: column_types}

      _ ->
        %TableMeta{}
    end
  end

  @impl true
  def get_table_structure(conn, table_name) do
    params = [table_name]

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
    WHERE c.table_name = $1
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
    WHERE tc.table_name = $1
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
    WHERE tc.table_name = $1
      AND tc.table_schema = 'public'
      AND tc.constraint_type = 'FOREIGN KEY'
    ORDER BY tc.constraint_name;
    """

    size_sql = """
    SELECT
      pg_size_pretty(pg_total_relation_size($1::text::regclass)) AS total_size,
      pg_size_pretty(pg_table_size($1::text::regclass)) AS table_size,
      pg_size_pretty(pg_indexes_size($1::text::regclass)) AS indexes_size,
      (SELECT reltuples::bigint FROM pg_class WHERE relname = $1::text) AS estimated_rows
    """

    check_sql = """
    SELECT
      conname AS constraint_name,
      pg_get_constraintdef(oid) AS definition
    FROM pg_constraint
    WHERE conrelid = $1::text::regclass
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
    WHERE t.relname = $1::text
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
    WHERE ccu.table_name = $1
      AND tc.table_schema = 'public'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND kcu.table_name != $1
    ORDER BY kcu.table_name, tc.constraint_name;
    """

    with {:ok, columns_result} <- DatabaseClient.query_and_normalize(conn, columns_sql, params),
         {:ok, constraints_result} <-
           DatabaseClient.query_and_normalize(conn, constraints_sql, params),
         {:ok, fk_result} <- DatabaseClient.query_and_normalize(conn, fk_sql, params),
         {:ok, size_result} <- DatabaseClient.query_and_normalize(conn, size_sql, params),
         {:ok, check_result} <- DatabaseClient.query_and_normalize(conn, check_sql, params),
         {:ok, indexes_result} <- DatabaseClient.query_and_normalize(conn, indexes_sql, params),
         {:ok, referenced_by_result} <-
           DatabaseClient.query_and_normalize(conn, referenced_by_sql, params) do
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

  @impl true
  def get_estimated_count(conn, table_name) do
    sql = "SELECT reltuples::bigint AS count FROM pg_class WHERE relname = $1::text"

    case DatabaseClient.query_and_normalize(conn, sql, [table_name]) do
      {:ok, %{rows: [%{"count" => count}]}} when count >= 0 ->
        count

      _ ->
        DatabaseClient.exact_count(conn, table_name)
    end
  end

  @impl true
  def get_all_relations(conn) do
    sql = """
    SELECT
      kcu.table_name AS from_table,
      kcu.column_name AS from_column,
      ccu.table_name AS to_table,
      ccu.column_name AS to_column
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage ccu
      ON tc.constraint_name = ccu.constraint_name
      AND tc.table_schema = ccu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema = 'public'
    ORDER BY kcu.table_name, kcu.column_name
    """

    conn
    |> DatabaseClient.query_and_normalize(sql)
    |> DatabaseClient.map_rows(fn row ->
      %{
        from_table: row["from_table"],
        from_column: row["from_column"],
        to_table: row["to_table"],
        to_column: row["to_column"]
      }
    end)
  end

  @impl true
  def get_functions(conn) do
    sql = """
    SELECT
      p.oid::text AS id,
      n.nspname AS schema,
      p.proname AS name,
      CASE p.prokind WHEN 'p' THEN 'procedure' ELSE 'function' END AS kind,
      pg_get_function_result(p.oid) AS return_type,
      pg_get_function_arguments(p.oid) AS arguments,
      l.lanname AS language
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_language l ON l.oid = p.prolang
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND p.prokind IN ('f', 'p')
    ORDER BY n.nspname, p.proname;
    """

    conn
    |> DatabaseClient.query_and_normalize(sql)
    |> DatabaseClient.map_rows(fn row ->
      %{
        id: row["id"],
        schema: row["schema"],
        name: row["name"],
        kind: if(row["kind"] == "procedure", do: :procedure, else: :function),
        return_type: row["return_type"],
        arguments: row["arguments"],
        language: row["language"]
      }
    end)
  end

  @impl true
  def get_function_definition(conn, id) do
    sql = "SELECT pg_get_functiondef($1::text::oid) AS definition"

    case DatabaseClient.query_and_normalize(conn, sql, [id]) do
      {:ok, %{rows: [%{"definition" => def} | _]}} when is_binary(def) -> {:ok, def}
      {:ok, _} -> {:error, "Function not found"}
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def get_triggers(conn) do
    sql = """
    SELECT
      t.oid::text AS id,
      t.tgname AS name,
      c.relname AS "table"
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE NOT t.tgisinternal
      AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY c.relname, t.tgname;
    """

    conn
    |> DatabaseClient.query_and_normalize(sql)
    |> DatabaseClient.map_rows(fn row ->
      %{id: row["id"], name: row["name"], table: row["table"]}
    end)
  end

  @impl true
  def get_trigger_definition(conn, id) do
    sql = "SELECT pg_get_triggerdef($1::text::oid) AS definition"

    case DatabaseClient.query_and_normalize(conn, sql, [id]) do
      {:ok, %{rows: [%{"definition" => def} | _]}} when is_binary(def) -> {:ok, def}
      {:ok, _} -> {:error, "Trigger not found"}
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def test_connection(database), do: DatabaseClient.test_connection_via_query(database)
end
