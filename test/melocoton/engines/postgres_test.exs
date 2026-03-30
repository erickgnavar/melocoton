defmodule Melocoton.Engines.PostgresTest do
  use ExUnit.Case, async: false

  alias Melocoton.ContainerHelper
  alias Melocoton.DatabaseClient
  alias Melocoton.Engines.Postgres
  alias Melocoton.Engines.{TableMeta, TableStructure}

  @moduletag :container

  @seed_sql [
    "CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE)",
    "CREATE TABLE posts (id SERIAL PRIMARY KEY, user_id INTEGER REFERENCES users(id), title TEXT, body TEXT)",
    "CREATE INDEX idx_posts_user_id ON posts(user_id)",
    "INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com')",
    "INSERT INTO users (name, email) VALUES ('Bob', 'bob@example.com')",
    "INSERT INTO posts (user_id, title, body) VALUES (1, 'Hello', 'World')"
  ]

  setup_all do
    {container, conn} = ContainerHelper.start_postgres(@seed_sql)

    on_exit(fn ->
      GenServer.stop(conn.pid)
      Testcontainers.stop_container(container.container_id)
    end)

    %{conn: conn}
  end

  describe "get_tables/1" do
    test "returns list of tables with columns", %{conn: conn} do
      {:ok, tables} = Postgres.get_tables(conn)

      table_names = Enum.map(tables, & &1.name)
      assert "users" in table_names
      assert "posts" in table_names

      users_table = Enum.find(tables, &(&1.name == "users"))
      col_names = Enum.map(users_table.cols, & &1.name)
      assert "id" in col_names
      assert "name" in col_names
      assert "email" in col_names
    end

    test "excludes system tables", %{conn: conn} do
      {:ok, tables} = Postgres.get_tables(conn)
      table_names = Enum.map(tables, & &1.name)

      refute Enum.any?(table_names, &String.starts_with?(&1, "pg_"))
    end

    test "tables are sorted by name", %{conn: conn} do
      {:ok, tables} = Postgres.get_tables(conn)
      names = Enum.map(tables, & &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "get_indexes/1" do
    test "returns indexes for public schema", %{conn: conn} do
      {:ok, indexes} = Postgres.get_indexes(conn)

      index_names = Enum.map(indexes, & &1.name)
      assert "idx_posts_user_id" in index_names

      idx = Enum.find(indexes, &(&1.name == "idx_posts_user_id"))
      assert idx.table == "posts"
    end

    test "includes primary key indexes", %{conn: conn} do
      {:ok, indexes} = Postgres.get_indexes(conn)
      tables = Enum.map(indexes, & &1.table)
      assert "users" in tables
      assert "posts" in tables
    end
  end

  describe "get_table_meta/2" do
    test "returns columns and pk for users table", %{conn: conn} do
      %TableMeta{} = meta = Postgres.get_table_meta(conn, "users")

      assert "id" in meta.columns
      assert "name" in meta.columns
      assert "email" in meta.columns
      assert meta.pk_columns == ["id"]
    end

    test "returns column types", %{conn: conn} do
      %TableMeta{} = meta = Postgres.get_table_meta(conn, "users")

      assert meta.column_types["id"] == "int4"
      assert meta.column_types["name"] == "text"
    end
  end

  describe "get_table_structure/2" do
    test "returns full structure for posts table", %{conn: conn} do
      {:ok, %TableStructure{} = structure} = Postgres.get_table_structure(conn, "posts")

      assert structure.pk_columns == ["id"]
      assert length(structure.columns) == 4

      assert length(structure.foreign_keys) == 1
      fk = hd(structure.foreign_keys)
      assert fk.column == "user_id"
      assert fk.foreign_table == "users"
      assert fk.foreign_column == "id"
    end

    test "returns indexes for the table", %{conn: conn} do
      {:ok, %TableStructure{} = structure} = Postgres.get_table_structure(conn, "posts")

      index_names = Enum.map(structure.indexes, & &1.name)
      assert "idx_posts_user_id" in index_names
    end

    test "returns unique constraints", %{conn: conn} do
      {:ok, %TableStructure{} = structure} = Postgres.get_table_structure(conn, "users")

      unique_names = Enum.map(structure.unique_constraints, & &1.name)
      assert Enum.any?(unique_names, &String.contains?(&1, "email"))
    end

    test "returns referenced_by for users table", %{conn: conn} do
      {:ok, %TableStructure{} = structure} = Postgres.get_table_structure(conn, "users")

      assert [_ | _] = structure.referenced_by
      ref = hd(structure.referenced_by)
      assert ref.foreign_table == "posts"
    end

    test "returns size information", %{conn: conn} do
      {:ok, %TableStructure{} = structure} = Postgres.get_table_structure(conn, "users")

      assert is_map(structure.size)
      assert Map.has_key?(structure.size, "total_size")
    end
  end

  describe "get_estimated_count/2" do
    test "returns a count for users table", %{conn: conn} do
      count = Postgres.get_estimated_count(conn, "users")
      assert is_integer(count)
      assert count >= 0
    end

    test "returns zero for empty table", %{conn: conn} do
      {:ok, _} =
        Melocoton.Connection.query(
          conn,
          "CREATE TABLE IF NOT EXISTS empty_table (id SERIAL PRIMARY KEY)"
        )

      count = Postgres.get_estimated_count(conn, "empty_table")
      assert count == 0
    end
  end

  describe "query execution via DatabaseClient" do
    test "executes SELECT and returns normalized result", %{conn: conn} do
      {:ok, result, meta} = DatabaseClient.query(conn, "SELECT name FROM users ORDER BY id")

      assert result.cols == ["name"]
      assert length(result.rows) == 2
      assert hd(result.rows)["name"] == "Alice"
      assert meta.total_time >= 0
    end

    test "returns error for invalid SQL", %{conn: conn} do
      {:error, message} = DatabaseClient.query(conn, "SELECT * FROM nonexistent_table")
      assert is_binary(message)
    end
  end
end
