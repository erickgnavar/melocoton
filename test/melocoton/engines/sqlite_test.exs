defmodule Melocoton.Engines.SqliteTest do
  use ExUnit.Case, async: true

  alias Melocoton.Connection
  alias Melocoton.Engines.Sqlite

  setup do
    db_path =
      Path.join(
        System.tmp_dir!(),
        "melocoton_sqlite_engine_test_#{System.unique_integer([:positive])}.db"
      )

    {:ok, raw_db} = Exqlite.Sqlite3.open(db_path)

    :ok =
      Exqlite.Sqlite3.execute(
        raw_db,
        "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)"
      )

    :ok =
      Exqlite.Sqlite3.execute(
        raw_db,
        "INSERT INTO users (name, email) VALUES ('Alice', 'a@b.com')"
      )

    :ok =
      Exqlite.Sqlite3.execute(raw_db, "INSERT INTO users (name, email) VALUES ('Bob', 'b@b.com')")

    :ok = Exqlite.Sqlite3.execute(raw_db, "CREATE TABLE empty_table (id INTEGER PRIMARY KEY)")
    Exqlite.Sqlite3.close(raw_db)

    {:ok, pid} = DBConnection.start_link(Exqlite.Connection, database: db_path, pool_size: 1)
    conn = %Connection{pid: pid, type: :sqlite}

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
      File.rm(db_path)
    end)

    %{conn: conn}
  end

  describe "get_estimated_count/2" do
    test "returns exact count for table with rows", %{conn: conn} do
      count = Sqlite.get_estimated_count(conn, "users")
      assert count == 2
    end

    test "returns zero for empty table", %{conn: conn} do
      count = Sqlite.get_estimated_count(conn, "empty_table")
      assert count == 0
    end
  end
end
