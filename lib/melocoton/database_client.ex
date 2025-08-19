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
    Melocoton.Engines.Postgres.get_tables(repo)
  end

  defp do_get_tables(repo, Ecto.Adapters.SQLite3) do
    Melocoton.Engines.Sqlite.get_tables(repo)
  end

  defp do_get_indexes(repo, Ecto.Adapters.Postgres) do
    Melocoton.Engines.Postgres.get_indexes(repo)
  end

  defp do_get_indexes(repo, Ecto.Adapters.SQLite3) do
    Melocoton.Engines.Sqlite.get_indexes(repo)
  end

  def handle_response(%{columns: cols, rows: rows, num_rows: num_rows}) do
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
