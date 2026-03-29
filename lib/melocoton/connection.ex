defmodule Melocoton.Connection do
  @enforce_keys [:pid, :type]
  defstruct [:pid, :type]

  @type t :: %__MODULE__{pid: pid(), type: :postgres | :sqlite | :mysql}

  # 30 second query timeout to prevent long-running queries from blocking indefinitely
  @query_timeout :timer.seconds(30)

  @doc """
  Quotes an identifier (table/column name) to prevent SQL injection.
  Escapes any embedded double quotes by doubling them.
  """
  def quote_identifier(name) when is_binary(name) do
    ~s("#{String.replace(name, "\"", "\"\"")}")
  end

  def query(%__MODULE__{pid: pid, type: :postgres}, sql) do
    case Postgrex.query(pid, sql, [], timeout: @query_timeout) do
      {:ok, %Postgrex.Result{columns: cols, rows: rows, num_rows: num_rows}} ->
        {:ok, %{columns: cols, rows: rows, num_rows: num_rows}}

      {:error, error} ->
        {:error, error}
    end
  end

  def query(%__MODULE__{pid: pid, type: :mysql}, sql) do
    case MyXQL.query(pid, sql, [], timeout: @query_timeout) do
      {:ok, %MyXQL.Result{columns: cols, rows: rows, num_rows: num_rows}} ->
        {:ok, %{columns: cols, rows: rows, num_rows: num_rows}}

      {:error, error} ->
        {:error, error}
    end
  end

  def query(%__MODULE__{pid: pid, type: :sqlite}, sql) do
    stmt = %Exqlite.Query{name: sql, statement: sql}

    case DBConnection.execute(pid, stmt, [], timeout: @query_timeout) do
      {:ok, _query, %Exqlite.Result{columns: cols, rows: rows, num_rows: num_rows}} ->
        {:ok, %{columns: cols, rows: rows, num_rows: num_rows}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Executes a function within a database transaction.
  The function receives a `%Connection{}` bound to the transaction connection.
  All queries inside the function use the same connection, ensuring atomicity.
  Returns `{:ok, result}` on commit or `{:error, reason}` on rollback.
  """
  def transaction(%__MODULE__{pid: pid, type: :postgres} = conn, fun) do
    Postgrex.transaction(
      pid,
      fn tx_conn -> fun.(%{conn | pid: tx_conn}) end,
      timeout: @query_timeout
    )
  end

  def transaction(%__MODULE__{pid: pid, type: :mysql} = conn, fun) do
    DBConnection.transaction(
      pid,
      fn tx_conn -> fun.(%{conn | pid: tx_conn}) end,
      timeout: @query_timeout
    )
  end

  def transaction(%__MODULE__{pid: pid, type: :sqlite} = conn, fun) do
    DBConnection.transaction(
      pid,
      fn tx_conn -> fun.(%{conn | pid: tx_conn}) end,
      timeout: @query_timeout
    )
  end
end
