defmodule MelocotonWeb.SQLLive.RunTest do
  use MelocotonWeb.ConnCase

  import Phoenix.LiveViewTest
  import Melocoton.DatabasesFixtures

  setup do
    db_path =
      Path.join(System.tmp_dir!(), "melocoton_test_#{System.unique_integer([:positive])}.db")

    {:ok, db} = Exqlite.Sqlite3.open(db_path)
    :ok = Exqlite.Sqlite3.execute(db, "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    :ok = Exqlite.Sqlite3.execute(db, "INSERT INTO users (name) VALUES ('alice')")
    :ok = Exqlite.Sqlite3.execute(db, "INSERT INTO users (name) VALUES ('bob')")
    Exqlite.Sqlite3.close(db)

    database = database_fixture(%{url: db_path, type: :sqlite})

    on_exit(fn -> File.rm(db_path) end)

    %{database: database}
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
end
