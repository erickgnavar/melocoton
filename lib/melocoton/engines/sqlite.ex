defmodule Melocoton.Engines.Sqlite do
  @behaviour Melocoton.Behaviours.Engine

  alias Melocoton.Connection
  alias Melocoton.Engines.{TableMeta, TableStructure}
  import Connection, only: [quote_identifier: 1]

  @impl true
  def get_tables(conn) do
    sql = """
    SELECT
      name, type
    FROM
      sqlite_schema
    WHERE
      type IN ('table', 'view') AND
      name NOT LIKE 'sqlite_%';
    """

    case Connection.query(conn, sql) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [name, schema_type] ->
          cols =
            case Connection.query(conn, "PRAGMA table_info(#{quote_identifier(name)});") do
              {:ok, result} ->
                result
                |> Melocoton.DatabaseClient.handle_response()
                |> Map.get(:rows)
                |> Enum.map(fn row ->
                  %{name: row["name"], type: row["type"]}
                end)

              {:error, _error} ->
                []
            end

          %{name: name, type: if(schema_type == "view", do: :view, else: :table), cols: cols}
        end)
        |> then(&{:ok, &1})

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def get_indexes(conn) do
    sql = "SELECT name, tbl_name FROM sqlite_master WHERE type = 'index';"

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
    case query_and_normalize(conn, "PRAGMA table_info(#{quote_identifier(table_name)})") do
      {:ok, %{rows: rows}} ->
        columns = Enum.map(rows, & &1["name"])
        column_types = Map.new(rows, fn r -> {r["name"], String.downcase(r["type"] || "")} end)

        pk_columns =
          rows
          |> Enum.filter(&(&1["pk"] != 0))
          |> Enum.sort_by(& &1["pk"])
          |> Enum.map(& &1["name"])

        %TableMeta{columns: columns, pk_columns: pk_columns, column_types: column_types}

      _ ->
        %TableMeta{}
    end
  end

  @impl true
  def get_table_structure(conn, table_name) do
    escaped = String.replace(table_name, "'", "''")
    quoted = quote_identifier(table_name)

    create_sql =
      "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = '#{escaped}'"

    columns_sql = "PRAGMA table_info(#{quoted})"
    fk_sql = "PRAGMA foreign_key_list(#{quoted})"
    index_sql = "PRAGMA index_list(#{quoted})"

    with {:ok, create_result} <- query_and_normalize(conn, create_sql),
         {:ok, columns_result} <- query_and_normalize(conn, columns_sql),
         {:ok, fk_result} <- query_and_normalize(conn, fk_sql),
         {:ok, index_result} <- query_and_normalize(conn, index_sql) do
      create_statement =
        case create_result.rows do
          [%{"sql" => sql} | _] -> sql
          _ -> nil
        end

      pk_columns =
        columns_result.rows
        |> Enum.filter(&(&1["pk"] != 0))
        |> Enum.sort_by(& &1["pk"])
        |> Enum.map(& &1["name"])

      columns =
        Enum.map(columns_result.rows, fn row ->
          %{
            "column_name" => row["name"],
            "data_type" => row["type"],
            "is_nullable" => if(row["notnull"] == 0, do: "YES", else: "NO"),
            "column_default" => row["dflt_value"]
          }
        end)

      foreign_keys =
        Enum.map(fk_result.rows, fn row ->
          %{
            name: "fk_#{row["from"]}_#{row["table"]}",
            column: row["from"],
            foreign_table: row["table"],
            foreign_column: row["to"]
          }
        end)

      indexes_with_cols =
        Enum.map(index_result.rows, fn row ->
          index_info_sql = "PRAGMA index_info(#{quote_identifier(row["name"])})"

          cols =
            case query_and_normalize(conn, index_info_sql) do
              {:ok, info} -> Enum.map(info.rows, & &1["name"])
              _ -> []
            end

          {row, cols}
        end)

      unique_constraints =
        indexes_with_cols
        |> Enum.filter(fn {row, _cols} -> row["unique"] == 1 end)
        |> Enum.map(fn {row, cols} -> %{name: row["name"], columns: cols} end)

      indexes =
        Enum.map(indexes_with_cols, fn {row, cols} ->
          %{name: row["name"], unique: row["unique"] == 1, columns: cols}
        end)

      check_constraints = parse_check_constraints(create_statement)
      referenced_by = get_referenced_by(conn, table_name)

      {:ok,
       %TableStructure{
         columns: columns,
         pk_columns: pk_columns,
         unique_constraints: unique_constraints,
         foreign_keys: foreign_keys,
         referenced_by: referenced_by,
         check_constraints: check_constraints,
         indexes: indexes,
         create_statement: create_statement
       }}
    end
  end

  defp parse_check_constraints(nil), do: []

  defp parse_check_constraints(create_sql) do
    # Match CONSTRAINT name CHECK(...) and bare CHECK(...) in CREATE TABLE
    ~r/(?:CONSTRAINT\s+(\w+)\s+)?CHECK\s*(\([^)]*(?:\([^)]*\))*[^)]*\))/i
    |> Regex.scan(create_sql)
    |> Enum.with_index(1)
    |> Enum.map(fn {match, idx} ->
      name = Enum.at(match, 1)
      definition = Enum.at(match, 2)
      name = if name in [nil, ""], do: "check_#{idx}", else: name
      %{name: name, definition: definition}
    end)
  end

  defp get_referenced_by(conn, table_name) do
    tables_sql =
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name != '#{String.replace(table_name, "'", "''")}'"

    case query_and_normalize(conn, tables_sql) do
      {:ok, %{rows: rows}} ->
        Enum.flat_map(rows, fn %{"name" => other_table} ->
          fk_sql = "PRAGMA foreign_key_list(#{quote_identifier(other_table)})"

          case query_and_normalize(conn, fk_sql) do
            {:ok, %{rows: fk_rows}} ->
              fk_rows
              |> Enum.filter(&(&1["table"] == table_name))
              |> Enum.map(fn row ->
                %{
                  name: "fk_#{other_table}_#{row["from"]}",
                  column: row["to"],
                  foreign_table: other_table,
                  foreign_column: row["from"]
                }
              end)

            _ ->
              []
          end
        end)

      _ ->
        []
    end
  end

  defp query_and_normalize(conn, sql) do
    case Connection.query(conn, sql) do
      {:ok, result} -> {:ok, Melocoton.DatabaseClient.handle_response(result)}
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def get_estimated_count(conn, table_name) do
    Melocoton.DatabaseClient.exact_count(conn, table_name)
  end

  @impl true
  def get_all_relations(conn) do
    tables_sql = "SELECT name FROM sqlite_master WHERE type = 'table'"

    case query_and_normalize(conn, tables_sql) do
      {:ok, %{rows: rows}} ->
        relations =
          Enum.flat_map(rows, fn %{"name" => table_name} ->
            fk_sql = "PRAGMA foreign_key_list(#{quote_identifier(table_name)})"

            case query_and_normalize(conn, fk_sql) do
              {:ok, %{rows: fk_rows}} ->
                Enum.map(fk_rows, fn row ->
                  %{
                    from_table: table_name,
                    from_column: row["from"],
                    to_table: row["table"],
                    to_column: row["to"]
                  }
                end)

              _ ->
                []
            end
          end)

        {:ok, relations}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def test_connection(database) do
    if File.exists?(database.url) do
      :ok
    else
      {:error, "File doesn't exist"}
    end
  end
end
