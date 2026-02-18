defmodule Melocoton.Connection do
  @enforce_keys [:pid, :type]
  defstruct [:pid, :type]

  @type t :: %__MODULE__{pid: pid(), type: :postgres | :sqlite}

  def query(%__MODULE__{pid: pid, type: :postgres}, sql) do
    case Postgrex.query(pid, sql, []) do
      {:ok, %Postgrex.Result{columns: cols, rows: rows, num_rows: num_rows}} ->
        {:ok, %{columns: cols, rows: rows, num_rows: num_rows}}

      {:error, error} ->
        {:error, error}
    end
  end

  def query(%__MODULE__{pid: pid, type: :sqlite}, sql) do
    stmt = %Exqlite.Query{name: sql, statement: sql}

    case DBConnection.execute(pid, stmt, []) do
      {:ok, _query, %Exqlite.Result{columns: cols, rows: rows, num_rows: num_rows}} ->
        {:ok, %{columns: cols, rows: rows, num_rows: num_rows}}

      {:error, error} ->
        {:error, error}
    end
  end
end
