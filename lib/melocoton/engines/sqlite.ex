defmodule Melocoton.Engines.Sqlite do
  @behaviour Melocoton.Behaviours.Engine

  alias Melocoton.Connection

  @impl true
  def get_tables(conn) do
    sql = """
    SELECT
      name
    FROM
      sqlite_schema
    WHERE
      type = 'table' AND
      name NOT LIKE 'sqlite_%';
    """

    case Connection.query(conn, sql) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(&Enum.at(&1, 0))
        |> Enum.map(fn name ->
          cols =
            case Connection.query(conn, "PRAGMA table_info(#{name});") do
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

          %{name: name, cols: cols}
        end)
        |> then(&{:ok, &1})

      {:error, _error} ->
        []
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
  def test_connection(database) do
    if File.exists?(database.url) do
      :ok
    else
      {:error, "File doesn't exist"}
    end
  end
end
