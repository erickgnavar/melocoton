defmodule Melocoton.Engines.Postgres do
  @behaviour Melocoton.Behaviours.Engine

  alias Melocoton.{DatabaseClient, Pool}

  @impl true
  def get_tables(repo) do
    sql = """
    SELECT table_name
    FROM information_schema.tables
    WHERE table_type = 'BASE TABLE' AND table_schema NOT IN ('pg_catalog', 'information_schema');
    """

    case repo.query(sql) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(&Enum.at(&1, 0))
        |> Enum.map(fn name ->
          cols =
            case repo.query(
                   "SELECT * FROM information_schema.columns WHERE table_schema = 'public' AND table_name = '#{name}';"
                 ) do
              {:ok, result} ->
                result
                |> DatabaseClient.handle_response()
                |> Map.get(:rows)
                |> Enum.map(fn row ->
                  %{name: row["column_name"], type: row["data_type"]}
                end)

              {:error, _error} ->
                []
            end

          %{name: name, cols: cols}
        end)
        |> then(&{:ok, &1})

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def get_indexes(repo) do
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

    case repo.query(sql) do
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
    repo = Pool.get_repo(database)

    case DatabaseClient.query(repo, "SELECT 1") do
      {:ok, _result, _meta} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
