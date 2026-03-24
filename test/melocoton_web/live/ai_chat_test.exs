defmodule MelocotonWeb.SqlLive.AiChatTest do
  use MelocotonWeb.ConnCase

  import Phoenix.LiveViewTest
  import Melocoton.DatabasesFixtures

  alias Melocoton.Databases

  defp create_test_db do
    db_path =
      Path.join(
        System.tmp_dir!(),
        "melocoton_ai_chat_test_#{System.unique_integer([:positive])}.db"
      )

    {:ok, db} = Exqlite.Sqlite3.open(db_path)
    :ok = Exqlite.Sqlite3.execute(db, "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    :ok = Exqlite.Sqlite3.execute(db, "INSERT INTO users (name) VALUES ('alice')")
    Exqlite.Sqlite3.close(db)

    db_path
  end

  setup do
    :sys.replace_state(Melocoton.Pool, fn _ -> %{} end)

    db_path = create_test_db()
    database = database_fixture(%{url: db_path, type: :sqlite})
    on_exit(fn -> File.rm(db_path) end)

    %{database: database, db_path: db_path}
  end

  describe "AI panel toggle" do
    test "AI panel is hidden by default", %{conn: conn, database: database} do
      {:ok, _live_view, html} = live(conn, ~p"/databases/#{database.id}/run")

      refute html =~ "Ask me about your database"
    end

    test "clicking robot icon opens AI panel", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      html =
        live_view
        |> element("[phx-click='toggle-ai-panel']")
        |> render_click()

      assert html =~ "AI Assistant"
      assert html =~ "Ask about your database"
    end

    test "clicking close button closes AI panel", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      # Open panel
      live_view
      |> element("[phx-click='toggle-ai-panel']")
      |> render_click()

      # Close via the close button in the component
      live_view
      |> element("[phx-click='close-panel']")
      |> render_click()

      html = render(live_view)
      refute html =~ "Ask me about your database"
    end
  end

  describe "chat messages" do
    test "shows empty state when no messages", %{conn: conn, database: database} do
      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      html =
        live_view
        |> element("[phx-click='toggle-ai-panel']")
        |> render_click()

      assert html =~ "Ask me about your database"
      assert html =~ "I know the schema"
    end

    test "displays persisted chat messages on mount", %{conn: conn, database: database} do
      # Pre-create messages in DB
      {:ok, _} =
        Databases.create_chat_message(%{
          role: "user",
          content: "show me all users",
          database_id: database.id
        })

      {:ok, _} =
        Databases.create_chat_message(%{
          role: "assistant",
          content: "```sql\nSELECT * FROM users;\n```",
          database_id: database.id
        })

      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      html =
        live_view
        |> element("[phx-click='toggle-ai-panel']")
        |> render_click()

      assert html =~ "show me all users"
      assert html =~ "SELECT * FROM users;"
    end

    test "clear-chat removes all messages", %{conn: conn, database: database} do
      {:ok, _} =
        Databases.create_chat_message(%{
          role: "user",
          content: "hello",
          database_id: database.id
        })

      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      live_view
      |> element("[phx-click='toggle-ai-panel']")
      |> render_click()

      html =
        live_view
        |> element("[phx-click='clear-chat']")
        |> render_click()

      assert html =~ "Ask me about your database"
      refute html =~ "hello"

      # Verify DB is cleared
      assert Databases.list_chat_messages(database.id) == []
    end
  end

  describe "SQL action buttons" do
    test "renders Insert and Run buttons for SQL code blocks", %{
      conn: conn,
      database: database
    } do
      {:ok, _} =
        Databases.create_chat_message(%{
          role: "assistant",
          content: "Here you go:\n\n```sql\nSELECT * FROM users;\n```\n",
          database_id: database.id
        })

      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      html =
        live_view
        |> element("[phx-click='toggle-ai-panel']")
        |> render_click()

      assert html =~ "phx-click=\"insert-sql\""
      assert html =~ "phx-click=\"run-sql\""
      assert html =~ "Insert"
      assert html =~ "Run"
    end

    test "insert-sql sends SQL to parent to load into editor", %{
      conn: conn,
      database: database
    } do
      {:ok, _} =
        Databases.create_chat_message(%{
          role: "assistant",
          content: "```sql\nSELECT * FROM users;\n```",
          database_id: database.id
        })

      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      live_view
      |> element("[phx-click='toggle-ai-panel']")
      |> render_click()

      # Click insert - this sends a message to the parent which pushes
      # a load-query event to JS. We verify no crash occurs.
      live_view
      |> element("[phx-click='insert-sql']")
      |> render_click()

      # Panel should still be open and functional
      html = render(live_view)
      assert html =~ "AI Assistant"
    end
  end

  describe "chat message persistence" do
    test "messages are stored in the database", %{database: database} do
      {:ok, msg} =
        Databases.create_chat_message(%{
          role: "user",
          content: "hello world",
          database_id: database.id
        })

      assert msg.role == "user"
      assert msg.content == "hello world"
      assert msg.database_id == database.id

      messages = Databases.list_chat_messages(database.id)
      assert length(messages) == 1
      assert hd(messages).content == "hello world"
    end

    test "clear_chat_messages removes all messages for a database", %{database: database} do
      for i <- 1..3 do
        Databases.create_chat_message(%{
          role: "user",
          content: "message #{i}",
          database_id: database.id
        })
      end

      assert length(Databases.list_chat_messages(database.id)) == 3

      Databases.clear_chat_messages(database.id)
      assert Databases.list_chat_messages(database.id) == []
    end

    test "messages are scoped to database", %{database: database} do
      other_db = database_fixture(%{url: "/tmp/other.db", type: :sqlite, name: "other"})

      Databases.create_chat_message(%{
        role: "user",
        content: "for db1",
        database_id: database.id
      })

      Databases.create_chat_message(%{
        role: "user",
        content: "for db2",
        database_id: other_db.id
      })

      db1_messages = Databases.list_chat_messages(database.id)
      db2_messages = Databases.list_chat_messages(other_db.id)

      assert length(db1_messages) == 1
      assert hd(db1_messages).content == "for db1"
      assert length(db2_messages) == 1
      assert hd(db2_messages).content == "for db2"
    end

    test "rejects invalid role", %{database: database} do
      assert {:error, %Ecto.Changeset{valid?: false}} =
               Databases.create_chat_message(%{
                 role: "invalid",
                 content: "hello",
                 database_id: database.id
               })
    end
  end
end
