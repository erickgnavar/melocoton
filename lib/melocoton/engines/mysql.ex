defmodule Melocoton.Engines.Mysql do
  @behaviour Melocoton.Behaviours.Engine

  alias Melocoton.{Connection, DatabaseClient, Pool}
  alias Melocoton.Engines.{TableMeta, TableStructure}

  @impl true
  def get_tables(conn) do
    sql = """
    SELECT t.TABLE_NAME, t.TABLE_TYPE, c.COLUMN_NAME, c.DATA_TYPE,
           c.IS_NULLABLE, c.COLUMN_DEFAULT
    FROM information_schema.TABLES t
    LEFT JOIN information_schema.COLUMNS c
      ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
    WHERE t.TABLE_TYPE IN ('BASE TABLE', 'VIEW')
      AND t.TABLE_SCHEMA = DATABASE()
    ORDER BY t.TABLE_NAME, c.ORDINAL_POSITION;
    """

    case Connection.query(conn, sql) do
      {:ok, %{rows: rows}} ->
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
        |> Enum.sort_by(& &1.name)
        |> then(&{:ok, &1})

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def get_indexes(conn) do
    sql = """
    SELECT DISTINCT
      INDEX_NAME,
      TABLE_NAME
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
    ORDER BY TABLE_NAME, INDEX_NAME;
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
  def get_table_meta(conn, table_name) do
    escaped = String.replace(table_name, "'", "''")

    sql = """
    SELECT
      c.COLUMN_NAME,
      c.DATA_TYPE,
      CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END AS is_pk
    FROM information_schema.COLUMNS c
    LEFT JOIN (
      SELECT COLUMN_NAME
      FROM information_schema.KEY_COLUMN_USAGE
      WHERE TABLE_NAME = '#{escaped}'
        AND TABLE_SCHEMA = DATABASE()
        AND CONSTRAINT_NAME = 'PRIMARY'
    ) pk ON pk.COLUMN_NAME = c.COLUMN_NAME
    WHERE c.TABLE_NAME = '#{escaped}'
      AND c.TABLE_SCHEMA = DATABASE()
    ORDER BY c.ORDINAL_POSITION
    """

    case query_and_normalize(conn, sql) do
      {:ok, %{rows: rows}} ->
        columns = Enum.map(rows, & &1["COLUMN_NAME"])
        column_types = Map.new(rows, fn r -> {r["COLUMN_NAME"], r["DATA_TYPE"]} end)

        pk_columns =
          rows
          |> Enum.filter(&(&1["is_pk"] == 1))
          |> Enum.map(& &1["COLUMN_NAME"])

        %TableMeta{columns: columns, pk_columns: pk_columns, column_types: column_types}

      _ ->
        %TableMeta{}
    end
  end

  @impl true
  def get_table_structure(conn, table_name) do
    escaped = String.replace(table_name, "'", "''")

    columns_sql = """
    SELECT
      COLUMN_NAME AS column_name,
      DATA_TYPE AS data_type,
      COLUMN_TYPE AS udt_name,
      IS_NULLABLE AS is_nullable,
      COLUMN_DEFAULT AS column_default,
      CHARACTER_MAXIMUM_LENGTH AS character_maximum_length,
      NUMERIC_PRECISION AS numeric_precision,
      NUMERIC_SCALE AS numeric_scale
    FROM information_schema.COLUMNS
    WHERE TABLE_NAME = '#{escaped}'
      AND TABLE_SCHEMA = DATABASE()
    ORDER BY ORDINAL_POSITION;
    """

    constraints_sql = """
    SELECT
      tc.CONSTRAINT_NAME AS constraint_name,
      tc.CONSTRAINT_TYPE AS constraint_type,
      kcu.COLUMN_NAME AS column_name
    FROM information_schema.TABLE_CONSTRAINTS tc
    JOIN information_schema.KEY_COLUMN_USAGE kcu
      ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
      AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
      AND tc.TABLE_NAME = kcu.TABLE_NAME
    WHERE tc.TABLE_NAME = '#{escaped}'
      AND tc.TABLE_SCHEMA = DATABASE()
    ORDER BY tc.CONSTRAINT_TYPE, tc.CONSTRAINT_NAME, kcu.ORDINAL_POSITION;
    """

    fk_sql = """
    SELECT
      tc.CONSTRAINT_NAME AS constraint_name,
      kcu.COLUMN_NAME AS column_name,
      kcu.REFERENCED_TABLE_NAME AS foreign_table,
      kcu.REFERENCED_COLUMN_NAME AS foreign_column
    FROM information_schema.TABLE_CONSTRAINTS tc
    JOIN information_schema.KEY_COLUMN_USAGE kcu
      ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
      AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
      AND tc.TABLE_NAME = kcu.TABLE_NAME
    WHERE tc.TABLE_NAME = '#{escaped}'
      AND tc.TABLE_SCHEMA = DATABASE()
      AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
    ORDER BY tc.CONSTRAINT_NAME;
    """

    size_sql = """
    SELECT
      CONCAT(ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024), ' kB') AS total_size,
      CONCAT(ROUND(DATA_LENGTH / 1024), ' kB') AS table_size,
      CONCAT(ROUND(INDEX_LENGTH / 1024), ' kB') AS indexes_size,
      TABLE_ROWS AS estimated_rows
    FROM information_schema.TABLES
    WHERE TABLE_NAME = '#{escaped}'
      AND TABLE_SCHEMA = DATABASE()
    """

    indexes_sql = """
    SELECT
      INDEX_NAME AS index_name,
      NOT NON_UNIQUE AS is_unique,
      GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns
    FROM information_schema.STATISTICS
    WHERE TABLE_NAME = '#{escaped}'
      AND TABLE_SCHEMA = DATABASE()
    GROUP BY INDEX_NAME, NON_UNIQUE
    ORDER BY INDEX_NAME;
    """

    referenced_by_sql = """
    SELECT
      tc.CONSTRAINT_NAME AS constraint_name,
      kcu.COLUMN_NAME AS column_name,
      kcu.TABLE_NAME AS foreign_table,
      kcu.REFERENCED_COLUMN_NAME AS foreign_column
    FROM information_schema.TABLE_CONSTRAINTS tc
    JOIN information_schema.KEY_COLUMN_USAGE kcu
      ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
      AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
      AND tc.TABLE_NAME = kcu.TABLE_NAME
    WHERE kcu.REFERENCED_TABLE_NAME = '#{escaped}'
      AND tc.TABLE_SCHEMA = DATABASE()
      AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
    ORDER BY kcu.TABLE_NAME, tc.CONSTRAINT_NAME;
    """

    check_sql = """
    SELECT
      cc.CONSTRAINT_NAME AS constraint_name,
      cc.CHECK_CLAUSE AS definition
    FROM information_schema.CHECK_CONSTRAINTS cc
    JOIN information_schema.TABLE_CONSTRAINTS tc
      ON cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
      AND cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
    WHERE cc.CONSTRAINT_SCHEMA = DATABASE()
      AND tc.TABLE_NAME = '#{escaped}'
      AND tc.CONSTRAINT_TYPE = 'CHECK'
    ORDER BY cc.CONSTRAINT_NAME;
    """

    create_sql = "SHOW CREATE TABLE `#{String.replace(table_name, "`", "``")}`"

    with {:ok, columns_result} <- query_and_normalize(conn, columns_sql),
         {:ok, constraints_result} <- query_and_normalize(conn, constraints_sql),
         {:ok, fk_result} <- query_and_normalize(conn, fk_sql),
         {:ok, size_result} <- query_and_normalize(conn, size_sql),
         {:ok, check_result} <- query_and_normalize(conn, check_sql),
         {:ok, indexes_result} <- query_and_normalize(conn, indexes_sql),
         {:ok, referenced_by_result} <- query_and_normalize(conn, referenced_by_sql),
         {:ok, create_result} <- query_and_normalize(conn, create_sql) do
      create_statement =
        case create_result.rows do
          [%{"Create Table" => sql} | _] -> sql
          _ -> nil
        end

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

      size_info =
        case size_result.rows do
          [row | _] -> row
          _ -> %{}
        end

      indexes =
        Enum.map(indexes_result.rows, fn row ->
          columns =
            case row["columns"] do
              nil -> []
              cols when is_binary(cols) -> String.split(cols, ",")
              cols -> cols
            end

          %{
            name: row["index_name"],
            unique: row["is_unique"] == 1,
            columns: columns
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

      check_constraints =
        Enum.map(check_result.rows, fn row ->
          %{name: row["constraint_name"], definition: row["definition"]}
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
         size: size_info,
         create_statement: create_statement
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
  def get_estimated_count(conn, table_name) do
    escaped = String.replace(table_name, "'", "''")

    sql =
      "SELECT TABLE_ROWS AS count FROM information_schema.TABLES WHERE TABLE_NAME = '#{escaped}' AND TABLE_SCHEMA = DATABASE()"

    case DatabaseClient.query(conn, sql) do
      {:ok, %{rows: [%{"count" => count}]}, _} when not is_nil(count) and count >= 0 ->
        count

      _ ->
        DatabaseClient.exact_count(conn, table_name)
    end
  end

  @impl true
  def get_all_relations(conn) do
    sql = """
    SELECT
      kcu.TABLE_NAME AS from_table,
      kcu.COLUMN_NAME AS from_column,
      kcu.REFERENCED_TABLE_NAME AS to_table,
      kcu.REFERENCED_COLUMN_NAME AS to_column
    FROM information_schema.KEY_COLUMN_USAGE kcu
    WHERE kcu.REFERENCED_TABLE_NAME IS NOT NULL
      AND kcu.TABLE_SCHEMA = DATABASE()
    ORDER BY kcu.TABLE_NAME, kcu.COLUMN_NAME
    """

    case query_and_normalize(conn, sql) do
      {:ok, %{rows: rows}} ->
        relations =
          Enum.map(rows, fn row ->
            %{
              from_table: row["from_table"],
              from_column: row["from_column"],
              to_table: row["to_table"],
              to_column: row["to_column"]
            }
          end)

        {:ok, relations}

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
