defmodule Melocoton.TransactionSession do
  @moduledoc """
  Manages interactive database transactions.

  Spawns a supervised process that holds a connection open inside a transaction.
  Queries are forwarded via message passing. Auto-rollbacks if the caller dies.
  """

  @query_timeout :timer.seconds(30)

  def start(conn, caller_pid) do
    Task.Supervisor.start_child(Melocoton.TransactionSession.Supervisor, fn ->
      run(conn, caller_pid)
    end)
  end

  def query(session_pid, sql) do
    call(session_pid, {:query, sql})
  end

  def commit(session_pid) do
    call(session_pid, :commit)
  end

  def rollback(session_pid) do
    call(session_pid, :rollback)
  end

  defp call(session_pid, message) do
    ref = make_ref()
    send(session_pid, {message, self(), ref})

    receive do
      {:result, ^ref, result} -> result
    after
      @query_timeout -> {:error, "Transaction timed out"}
    end
  end

  defp run(%{pid: pid, type: type}, caller_pid) do
    Process.monitor(caller_pid)

    DBConnection.transaction(
      pid,
      fn conn -> receive_loop(conn, type, caller_pid) end,
      timeout: :infinity
    )
  end

  defp receive_loop(conn, type, caller_pid) do
    receive do
      {{:query, sql}, from, ref} ->
        result = execute(conn, type, sql)
        send(from, {:result, ref, result})
        receive_loop(conn, type, caller_pid)

      {:commit, from, ref} ->
        send(from, {:result, ref, :ok})
        :ok

      {:rollback, from, ref} ->
        send(from, {:result, ref, :ok})
        DBConnection.rollback(conn, :rollback)

      {:DOWN, _ref, :process, ^caller_pid, _reason} ->
        DBConnection.rollback(conn, :caller_down)
    end
  end

  defp execute(conn, :postgres, sql) do
    case Postgrex.query(conn, sql, [], timeout: @query_timeout) do
      {:ok, %Postgrex.Result{columns: cols, rows: rows, num_rows: num_rows}} ->
        {:ok, %{columns: cols, rows: rows, num_rows: num_rows}}

      {:error, error} ->
        {:error, error}
    end
  end

  # Uses TextQuery + DBConnection.execute instead of MyXQL.query because the latter
  # goes through prepare_execute which can bypass the transaction-bound connection.
  defp execute(conn, :mysql, sql) do
    query = %MyXQL.TextQuery{statement: sql}

    case DBConnection.execute(conn, query, [], timeout: @query_timeout) do
      {:ok, _query, %MyXQL.Result{columns: cols, rows: rows, num_rows: num_rows}} ->
        {:ok, %{columns: cols, rows: rows, num_rows: num_rows}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp execute(conn, :sqlite, sql) do
    stmt = %Exqlite.Query{name: sql, statement: sql}

    case DBConnection.execute(conn, stmt, [], timeout: @query_timeout) do
      {:ok, _query, %Exqlite.Result{columns: cols, rows: rows, num_rows: num_rows}} ->
        {:ok, %{columns: cols, rows: rows, num_rows: num_rows}}

      {:error, error} ->
        {:error, error}
    end
  end
end
