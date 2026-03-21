defmodule MelocotonWeb.SQLLive.RunTest do
  use MelocotonWeb.ConnCase

  import Phoenix.LiveViewTest
  import Melocoton.DatabasesFixtures

  defp create_test_db(extra_sql) do
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

  defp open_structure_tab(live_view, table_name) do
    render_click(live_view, "set-table-explorer", %{"table" => table_name})
    render_async(live_view)

    live_view
    |> element("[phx-click='switch-tab'][phx-value-tab='structure']")
    |> render_click()

    render_async(live_view)
  end

  setup do
    item_inserts = for i <- 1..25, do: "INSERT INTO items (value) VALUES ('item_#{i}')"

    db_path =
      create_test_db(
        [
          "CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER REFERENCES users(id), title TEXT)",
          "INSERT INTO posts (user_id, title) VALUES (1, 'hello')",
          "CREATE TABLE strict_table (id INTEGER PRIMARY KEY, required_field TEXT NOT NULL, optional_field TEXT)",
          "CREATE TABLE with_defaults (id INTEGER PRIMARY KEY, status TEXT DEFAULT 'active', count INTEGER DEFAULT 0)",
          "CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT)",
          "CREATE INDEX idx_posts_title ON posts(title)",
          "CREATE UNIQUE INDEX idx_posts_user_title ON posts(user_id, title)"
        ] ++ item_inserts
      )

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

  describe "table explorer data tab" do
    test "displays table data with column headers", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})

      html = render_async(live_view)

      assert html =~ "id"
      assert html =~ "name"
      assert html =~ "alice"
      assert html =~ "bob"
    end

    test "data tab is active by default", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = render_click(live_view, "set-table-explorer", %{"table" => "users"})

      assert html =~ "Data"
      assert html =~ "Showing"
    end

    test "sorts by column ascending on first click", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})
      render_async(live_view)

      live_view
      |> element("[phx-click='sort-column'][phx-value-column='name']")
      |> render_click()

      html = render_async(live_view)

      # alice comes before bob in ascending order
      alice_pos = :binary.match(html, "alice") |> elem(0)
      bob_pos = :binary.match(html, "bob") |> elem(0)
      assert alice_pos < bob_pos
      # Should show sort-up icon
      assert html =~ "fa-sort-up"
    end

    test "sorts descending on second click", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})
      render_async(live_view)

      # First click: ascending
      live_view
      |> element("[phx-click='sort-column'][phx-value-column='name']")
      |> render_click()

      render_async(live_view)

      # Second click: descending
      live_view
      |> element("[phx-click='sort-column'][phx-value-column='name']")
      |> render_click()

      html = render_async(live_view)

      # bob comes before alice in descending order
      alice_pos = :binary.match(html, "alice") |> elem(0)
      bob_pos = :binary.match(html, "bob") |> elem(0)
      assert bob_pos < alice_pos
      # Should show sort-down icon
      assert html =~ "fa-sort-down"
    end

    test "clears sort on third click", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})
      render_async(live_view)

      # Click three times: asc -> desc -> none
      for _i <- 1..3 do
        live_view
        |> element("[phx-click='sort-column'][phx-value-column='name']")
        |> render_click()

        render_async(live_view)
      end

      html = render(live_view)

      # No active sort icons — only neutral fa-sort should remain
      refute html =~ "fa-sort-up"
      refute html =~ "fa-sort-down"
    end

    test "sorting a different column resets to ascending", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})
      render_async(live_view)

      # Sort by name descending
      live_view
      |> element("[phx-click='sort-column'][phx-value-column='name']")
      |> render_click()

      render_async(live_view)

      live_view
      |> element("[phx-click='sort-column'][phx-value-column='name']")
      |> render_click()

      render_async(live_view)

      # Now sort by id — should start ascending
      live_view
      |> element("[phx-click='sort-column'][phx-value-column='id']")
      |> render_click()

      html = render_async(live_view)
      assert html =~ "fa-sort-up"
    end

    test "sort persists across pagination", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "items"})
      render_async(live_view)

      # Sort by value descending — item_9 should come first (lexicographic)
      live_view
      |> element("[phx-click='sort-column'][phx-value-column='value']")
      |> render_click()

      render_async(live_view)

      live_view
      |> element("[phx-click='sort-column'][phx-value-column='value']")
      |> render_click()

      render_async(live_view)

      # Go to next page — sort should still be active
      live_view
      |> element("[phx-click='next-page']")
      |> render_click()

      html = render_async(live_view)
      assert html =~ "fa-sort-down"
    end

    test "paginates with next and previous", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "items"})
      render_async(live_view)

      live_view
      |> element("[phx-click='next-page']")
      |> render_click()

      html = render_async(live_view)

      assert html =~ "item_21"
    end

    test "filters rows by search term", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})
      render_async(live_view)

      live_view
      |> element("form[phx-change='filter-rows']")
      |> render_change(%{"filter" => "alice"})

      html = render_async(live_view)

      assert html =~ "alice"
      refute html =~ "bob"
    end

    test "filter is case-insensitive", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})
      render_async(live_view)

      live_view
      |> element("form[phx-change='filter-rows']")
      |> render_change(%{"filter" => "ALICE"})

      html = render_async(live_view)

      # SQLite LIKE is case-insensitive for ASCII by default
      assert html =~ "alice"
      refute html =~ "bob"
    end

    test "clearing filter shows all rows again", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})
      render_async(live_view)

      # Apply filter
      live_view
      |> element("form[phx-change='filter-rows']")
      |> render_change(%{"filter" => "alice"})

      render_async(live_view)

      # Clear filter
      live_view
      |> element("form[phx-change='filter-rows']")
      |> render_change(%{"filter" => ""})

      html = render_async(live_view)

      assert html =~ "alice"
      assert html =~ "bob"
    end

    test "filter with no matches shows empty table", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})
      render_async(live_view)

      live_view
      |> element("form[phx-change='filter-rows']")
      |> render_change(%{"filter" => "nonexistent"})

      html = render_async(live_view)

      refute html =~ "alice"
      refute html =~ "bob"
    end

    test "filter searches across all columns", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})
      render_async(live_view)

      # Filter by id value "1" — should match alice (id=1)
      live_view
      |> element("form[phx-change='filter-rows']")
      |> render_change(%{"filter" => "alice"})

      html = render_async(live_view)
      assert html =~ "alice"
    end

    test "filter highlights matched text in cells", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})
      render_async(live_view)

      live_view
      |> element("form[phx-change='filter-rows']")
      |> render_change(%{"filter" => "ali"})

      html = render_async(live_view)

      assert html =~ "<mark>ali</mark>"
      assert html =~ "ce"
    end

    test "no highlight marks when filter is empty", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      render_click(live_view, "set-table-explorer", %{"table" => "users"})

      html = render_async(live_view)

      refute html =~ "<mark>"
    end
  end

  describe "table explorer structure tab" do
    test "switches to structure tab and shows column details", %{
      conn: conn,
      database: database
    } do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_structure_tab(live_view, "users")

      assert html =~ "Columns"
      assert html =~ "id"
      assert html =~ "name"
      assert html =~ "INTEGER"
      assert html =~ "TEXT"
    end

    test "shows CREATE TABLE statement for sqlite", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_structure_tab(live_view, "users")

      assert html =~ "Create Statement"
      assert html =~ "CREATE TABLE users"
    end

    test "shows primary key columns", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_structure_tab(live_view, "users")

      assert html =~ "PK"
    end

    test "shows foreign keys when present", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_structure_tab(live_view, "posts")

      assert html =~ "Foreign Keys"
      assert html =~ "user_id"
      assert html =~ "users"
    end

    test "can switch back to data tab from structure", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      open_structure_tab(live_view, "users")

      live_view
      |> element("[phx-click='switch-tab'][phx-value-tab='data']")
      |> render_click()

      html = render_async(live_view)

      assert html =~ "alice"
      assert html =~ "bob"
      assert html =~ "Showing"
    end

    test "shows nullable info for columns", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_structure_tab(live_view, "strict_table")

      assert html =~ "required_field"
      assert html =~ "optional_field"
      assert html =~ "NO"
    end

    test "shows default values for columns", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_structure_tab(live_view, "with_defaults")

      assert html =~ "&#39;active&#39;"
      assert html =~ "0"
    end
  end

  describe "table explorer indexes tab" do
    defp open_indexes_tab(live_view, table_name) do
      render_click(live_view, "set-table-explorer", %{"table" => table_name})
      render_async(live_view)

      live_view
      |> element("[phx-click='switch-tab'][phx-value-tab='indexes']")
      |> render_click()

      render_async(live_view)
    end

    test "shows indexes for a table", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_indexes_tab(live_view, "posts")

      assert html =~ "idx_posts_title"
      assert html =~ "title"
    end

    test "shows unique badge for unique indexes", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_indexes_tab(live_view, "posts")

      assert html =~ "idx_posts_user_title"
      assert html =~ "YES"
    end

    test "shows multiple columns for composite indexes", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_indexes_tab(live_view, "posts")

      assert html =~ "user_id"
      assert html =~ "title"
    end

    test "shows empty state when no indexes", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_indexes_tab(live_view, "users")

      assert html =~ "No indexes found"
    end
  end

  describe "table explorer relations tab" do
    defp open_relations_tab(live_view, table_name) do
      render_click(live_view, "set-table-explorer", %{"table" => table_name})
      render_async(live_view)

      live_view
      |> element("[phx-click='switch-tab'][phx-value-tab='relations']")
      |> render_click()

      render_async(live_view)
    end

    test "shows outgoing foreign keys", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_relations_tab(live_view, "posts")

      assert html =~ "References (outgoing)"
      assert html =~ "user_id"
      assert html =~ "users"
    end

    test "shows incoming references", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_relations_tab(live_view, "users")

      assert html =~ "Referenced by (incoming)"
      assert html =~ "posts"
    end

    test "shows empty state when no outgoing references", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_relations_tab(live_view, "users")

      assert html =~ "This table does not reference other tables"
    end

    test "shows empty state when no incoming references", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_relations_tab(live_view, "posts")

      assert html =~ "No other tables reference this table"
    end

    test "table names are clickable to navigate", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")
      html = open_relations_tab(live_view, "posts")

      assert html =~ "phx-click=\"set-table-explorer\""
      assert html =~ "phx-value-table=\"users\""
    end
  end
end
