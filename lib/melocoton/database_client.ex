defmodule Melocoton.DatabaseClient do
  @moduledoc """
  Get information about a database repository
  """

  def query(repo, sql) do
    init_time = System.monotonic_time(:nanosecond)
    result = repo.query(sql, [])
    end_time = System.monotonic_time(:nanosecond)
    total_time = System.convert_time_unit(end_time - init_time, :nanosecond, :millisecond)

    case result do
      {:ok, result} ->
        {:ok, handle_response(result), %{total_time: total_time}}

      {:error, error} ->
        {:error, translate_query_error(error)}
    end
  end

  # TODO: make specific structs for each database object
  @spec get_tables(atom) :: {:ok, [map]} | {:error, String.t()}
  def get_tables(repo) do
    do_get_tables(repo, repo.__adapter__())
  end

  @spec get_indexes(atom) :: {:ok, [map]} | {:error, String.t()}
  def get_indexes(repo) do
    do_get_indexes(repo, repo.__adapter__())
  end

  defp translate_query_error(%Postgrex.Error{postgres: %{message: message}}), do: message
  defp translate_query_error(%Exqlite.Error{message: message}), do: message
  defp translate_query_error(%DBConnection.ConnectionError{message: message}), do: message
  defp translate_query_error(%Postgrex.QueryError{message: message}), do: message

  defp do_get_tables(repo, Ecto.Adapters.Postgres) do
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
                |> handle_response()
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

  defp do_get_tables(repo, Ecto.Adapters.SQLite3) do
    sql = """
    SELECT
      name
    FROM
      sqlite_schema
    WHERE
      type = 'table' AND
      name NOT LIKE 'sqlite_%';
    """

    case repo.query(sql) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(&Enum.at(&1, 0))
        |> Enum.map(fn name ->
          cols =
            case repo.query("PRAGMA table_info(#{name});") do
              {:ok, result} ->
                result
                |> handle_response()
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

  defp do_get_indexes(repo, Ecto.Adapters.Postgres) do
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

  defp do_get_indexes(repo, Ecto.Adapters.SQLite3) do
    sql = "SELECT name, tbl_name FROM sqlite_master WHERE type = 'index';"

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

  defp handle_response(%{columns: cols, rows: rows, num_rows: num_rows}) do
    cols = cols || []

    rows =
      rows
      |> Kernel.||([])
      |> Enum.map(&Enum.zip(cols, normalize_value(&1)))
      |> Enum.map(&Enum.into(&1, %{}))

    %{cols: cols, rows: rows, num_rows: num_rows}
  end

  defp normalize_value(values) do
    Enum.map(values, fn
      # handle uuid columns that are returned as raw binary data
      <<raw_uuid::binary-size(16)>> ->
        case Ecto.UUID.cast(raw_uuid) do
          {:ok, casted_value} ->
            casted_value

          :error ->
            "ERROR"
        end

      value when is_map(value) ->
        Jason.encode!(value)

      value ->
        value
    end)
  end
end
