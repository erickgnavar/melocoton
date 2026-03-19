defmodule MelocotonWeb.SQLLive.RunTest do
  use MelocotonWeb.ConnCase

  import Phoenix.LiveViewTest
  import Melocoton.DatabasesFixtures

  defp create_test_db(extra_sql \\ []) do
    db_path =
      Path.join(System.tmp_dir!(), "melocoton_test_#{System.unique_integer([:positive])}.db")

    {:ok, db} = Exqlite.Sqlite3.open(db_path)
    :ok = Exqlite.Sqlite3.execute(db, "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    :ok = Exqlite.Sqlite3.execute(db, "INSERT INTO users (name) VALUES ('alice')")
    :ok = Exqlite.Sqlite3.execute(db, "INSERT INTO users (name) VALUES ('bob')")
    Enum.each(extra_sql, &Exqlite.Sqlite3.execute(db, &1))
    Exqlite.Sqlite3.close(db)

    db_path
  end

  setup do
    db_path = create_test_db()
    database = database_fixture(%{url: db_path, type: :sqlite})

    on_exit(fn -> File.rm(db_path) end)

    %{database: database, db_path: db_path}
  end

  describe "Run LiveView" do
    test "mounts and renders the database name", %{conn: conn, database: database} do
      {:ok, _live, html} = live(conn, ~p"/databases/#{database.id}/run")

      assert html =~ database.name
    end

    test "renders table explorer when a table is selected", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      html =
        render_click(live_view, "set-table-explorer", %{"table" => "users"})

      assert html =~ "table-name"
      assert html =~ "users"
    end
  end

  describe "table explorer with special table names" do
    test "renders table explorer for a table name with spaces", %{conn: conn} do
      db_path =
        create_test_db([
          ~s[CREATE TABLE "my table" (id INTEGER PRIMARY KEY, value TEXT)],
          ~s[INSERT INTO "my table" (value) VALUES ('test')]
        ])

      database = database_fixture(%{url: db_path, type: :sqlite, name: "special-tables"})
      on_exit(fn -> File.rm(db_path) end)

      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      html = render_click(live_view, "set-table-explorer", %{"table" => "my table"})

      assert html =~ "my table"
      assert html =~ "table-name"
    end

    test "renders table explorer for a table name with double quotes", %{conn: conn} do
      db_path =
        create_test_db([
          ~s[CREATE TABLE "my""quoted" (id INTEGER PRIMARY KEY, value TEXT)],
          ~s[INSERT INTO "my""quoted" (value) VALUES ('test')]
        ])

      database = database_fixture(%{url: db_path, type: :sqlite, name: "quoted-tables"})
      on_exit(fn -> File.rm(db_path) end)

      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      html = render_click(live_view, "set-table-explorer", %{"table" => ~s(my"quoted)})

      assert html =~ "table-name"
    end

    test "handles SQL injection attempt in table name safely", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      # This should not execute the DROP TABLE — it should just fail gracefully
      html =
        render_click(
          live_view,
          "set-table-explorer",
          %{"table" => ~s(users"; DROP TABLE users; --)}
        )

      # The table explorer renders but the async query will fail (table doesn't exist)
      assert html =~ "table-name"
    end
  end
end
