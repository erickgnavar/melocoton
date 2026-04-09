defmodule MelocotonWeb.DatabaseLiveTest do
  use MelocotonWeb.ConnCase

  import Phoenix.LiveViewTest
  import Melocoton.DatabasesFixtures

  @create_attrs %{name: "some name", type: "sqlite", url: "/tmp/data.db"}
  @update_attrs %{
    name: "some updated name",
    type: "sqlite",
    url: "/tmp/updated.db"
  }
  @invalid_attrs %{name: nil, type: :sqlite, url: nil}

  defp create_database(_) do
    database = database_fixture()
    %{database: database}
  end

  describe "Index" do
    setup [:create_database]

    test "lists all databases", %{conn: conn, database: database} do
      {:ok, _index_live, html} = live(conn, ~p"/databases")

      assert html =~ "Listing Databases"
      assert html =~ database.name
    end

    test "saves new database", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")

      assert index_live |> element("a", "New Connection") |> render_click() =~
               "New Database"

      assert_patch(index_live, ~p"/databases/new")

      assert index_live
             |> form("#database-form", database: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#database-form", database: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/databases")

      html = render(index_live)
      assert html =~ "Database created successfully"
      assert html =~ "some name"
    end

    test "updates database in listing", %{conn: conn, database: database} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")

      assert index_live |> element("#databases-#{database.id} a[title='Edit']") |> render_click() =~
               "Edit Database"

      assert_patch(index_live, ~p"/databases/#{database}/edit")

      assert index_live
             |> form("#database-form", database: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#database-form", database: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/databases")

      html = render(index_live)
      assert html =~ "Database updated successfully"
      assert html =~ "some updated name"
    end

    test "clones database in listing", %{conn: conn, database: database} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")

      assert index_live
             |> element("#databases-#{database.id} button[title='Clone']")
             |> render_click()

      html = render(index_live)
      assert html =~ "Connection cloned"
      assert html =~ "#{database.name} (copy)"
    end

    test "deletes database in listing", %{conn: conn, database: database} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")

      assert index_live
             |> element("#databases-#{database.id} a[title='Delete']")
             |> render_click()

      refute has_element?(index_live, "#databases-#{database.id}")
    end
  end

  describe "Connection string parsing" do
    setup [:create_database]

    test "fills postgres fields from connection string", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")
      index_live |> element("a", "New Connection") |> render_click()

      # Switch to postgres type first
      index_live
      |> form("#database-form", database: %{type: "postgres", name: "test db"})
      |> render_change()

      # Paste a connection string
      index_live
      |> element("input[name=connection_string]")
      |> render_change(%{connection_string: "postgres://admin:secret@db.example.com:5433/myapp"})

      html = render(index_live)
      assert html =~ "db.example.com"
      assert html =~ "5433"
      assert html =~ "admin"
      assert html =~ "myapp"
    end

    test "preserves name when filling from connection string", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")
      index_live |> element("a", "New Connection") |> render_click()

      index_live
      |> form("#database-form", database: %{type: "postgres", name: "My Production DB"})
      |> render_change()

      index_live
      |> element("input[name=connection_string]")
      |> render_change(%{connection_string: "postgres://user:pass@host:5432/db"})

      html = render(index_live)
      assert html =~ "My Production DB"
      assert html =~ "host"
    end

    test "fills mysql fields from connection string", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")
      index_live |> element("a", "New Connection") |> render_click()

      index_live
      |> form("#database-form", database: %{type: "mysql"})
      |> render_change()

      index_live
      |> element("input[name=connection_string]")
      |> render_change(%{connection_string: "mysql://root:pass@mysql-host:3307/shop"})

      html = render(index_live)
      assert html =~ "mysql-host"
      assert html =~ "3307"
      assert html =~ "root"
      assert html =~ "shop"
    end

    test "handles connection string without password", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")
      index_live |> element("a", "New Connection") |> render_click()

      index_live
      |> form("#database-form", database: %{type: "postgres"})
      |> render_change()

      index_live
      |> element("input[name=connection_string]")
      |> render_change(%{connection_string: "postgres://readonly@host/analytics"})

      html = render(index_live)
      assert html =~ "readonly"
      assert html =~ "analytics"
    end

    test "handles invalid connection string gracefully", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")
      index_live |> element("a", "New Connection") |> render_click()

      index_live
      |> form("#database-form", database: %{type: "postgres"})
      |> render_change()

      # Should not crash, falls back to defaults
      index_live
      |> element("input[name=connection_string]")
      |> render_change(%{connection_string: "not-a-valid-url"})

      html = render(index_live)
      assert html =~ "PostgreSQL Connection"
    end

    test "can submit form after filling from connection string", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")
      index_live |> element("a", "New Connection") |> render_click()

      index_live
      |> form("#database-form",
        database: %{
          type: "postgres",
          name: "from string",
          group_id: hd(Melocoton.Databases.list_groups()).id
        }
      )
      |> render_change()

      index_live
      |> element("input[name=connection_string]")
      |> render_change(%{connection_string: "postgres://user:pass@host:5432/mydb"})

      index_live
      |> form("#database-form", database: %{})
      |> render_submit()

      assert_patch(index_live, ~p"/databases")
      html = render(index_live)
      assert html =~ "Database created successfully"
      assert html =~ "from string"
    end
  end

  describe "Database form postgres fields" do
    setup [:create_database]

    test "shows postgres fields when type is postgres", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")

      index_live |> element("a", "New Connection") |> render_click()

      html =
        index_live
        |> form("#database-form", database: %{type: "postgres"})
        |> render_change()

      assert html =~ "PostgreSQL Connection"
      assert html =~ "Host"
      assert html =~ "Port"
      assert html =~ "User"
      assert html =~ "Password"
      assert html =~ "Database"
      refute html =~ "File path"
    end

    test "shows sqlite file path when type is sqlite", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")

      index_live |> element("a", "New Connection") |> render_click()

      html =
        index_live
        |> form("#database-form", database: %{type: "sqlite"})
        |> render_change()

      assert html =~ "SQLite Connection"
      assert html =~ "File path"
      refute html =~ "PostgreSQL Connection"
    end

    test "builds postgres url from individual fields", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")

      index_live |> element("a", "New Connection") |> render_click()

      # First switch type to postgres so the form shows pg fields
      index_live
      |> form("#database-form", database: %{type: "postgres"})
      |> render_change()

      # Now submit with postgres fields
      index_live
      |> form("#database-form",
        database: %{
          name: "my pg db",
          type: "postgres",
          pg_host: "db.example.com",
          pg_port: "5432",
          pg_user: "admin",
          pg_password: "secret",
          pg_database: "myapp",
          group_id: hd(Melocoton.Databases.list_groups()).id
        }
      )
      |> render_submit()

      assert_patch(index_live, ~p"/databases")

      html = render(index_live)
      assert html =~ "my pg db"
      assert html =~ "Database created successfully"
    end

    test "parses existing postgres url into fields on edit", %{conn: conn} do
      pg_db =
        database_fixture(%{
          name: "pg test",
          type: :postgres,
          url: "postgres://myuser:mypass@dbhost:5433/testdb"
        })

      {:ok, index_live, _html} = live(conn, ~p"/databases")

      index_live
      |> element("#databases-#{pg_db.id} a[title='Edit']")
      |> render_click()

      html = render(index_live)

      assert html =~ "PostgreSQL Connection"
      assert html =~ "dbhost"
      assert html =~ "5433"
      assert html =~ "myuser"
      assert html =~ "testdb"
    end
  end
end
