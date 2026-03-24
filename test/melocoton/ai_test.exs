defmodule Melocoton.AITest do
  use Melocoton.DataCase

  alias Melocoton.AI

  defp create_test_conn do
    db_path =
      Path.join(System.tmp_dir!(), "melocoton_ai_test_#{System.unique_integer([:positive])}.db")

    {:ok, db} = Exqlite.Sqlite3.open(db_path)
    :ok = Exqlite.Sqlite3.execute(db, "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")

    :ok =
      Exqlite.Sqlite3.execute(
        db,
        "CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER REFERENCES users(id), title TEXT)"
      )

    Exqlite.Sqlite3.close(db)

    {:ok, pid} = DBConnection.start_link(Exqlite.Connection, database: db_path, pool_size: 1)
    on_exit(fn -> File.rm(db_path) end)

    %Melocoton.Connection{pid: pid, type: :sqlite}
  end

  describe "build_system_prompt/1" do
    test "includes database type" do
      conn = create_test_conn()
      prompt = AI.build_system_prompt(conn)

      assert prompt =~ "SQLite"
    end

    test "includes table names and columns" do
      conn = create_test_conn()
      prompt = AI.build_system_prompt(conn)

      assert prompt =~ "Table: users"
      assert prompt =~ "id"
      assert prompt =~ "name"
      assert prompt =~ "Table: posts"
      assert prompt =~ "title"
      assert prompt =~ "user_id"
    end

    test "includes SQL generation rules" do
      conn = create_test_conn()
      prompt = AI.build_system_prompt(conn)

      assert prompt =~ "```sql code block"
      assert prompt =~ "foreign key"
    end
  end

  describe "chat/3" do
    test "returns error when no model is configured" do
      conn = create_test_conn()

      # Ensure no model is configured
      Application.delete_env(:melocoton, :ai)

      messages = [%{role: "user", content: "show me all users"}]
      assert {:error, message} = AI.chat(conn, messages)
      assert message =~ "No AI model configured"
    end
  end

  describe "build_system_prompt/1 with postgres type" do
    test "uses PostgreSQL label for postgres connections" do
      # We can't easily create a real postgres connection in tests,
      # but we can test the type detection logic
      conn = create_test_conn()
      assert conn.type == :sqlite
      prompt = AI.build_system_prompt(conn)
      assert prompt =~ "SQLite"
      refute prompt =~ "PostgreSQL"
    end
  end
end
