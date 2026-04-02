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
    {:ok, chat} = Databases.get_or_create_active_chat(database.id)
    on_exit(fn -> File.rm(db_path) end)

    %{database: database, db_path: db_path, chat: chat}
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

    test "displays persisted chat messages on mount", %{
      conn: conn,
      database: database,
      chat: chat
    } do
      {:ok, _} =
        Databases.create_chat_message(%{
          role: "user",
          content: "show me all users",
          database_id: database.id,
          chat_id: chat.id
        })

      {:ok, _} =
        Databases.create_chat_message(%{
          role: "assistant",
          content: "```sql\nSELECT * FROM users;\n```",
          database_id: database.id,
          chat_id: chat.id
        })

      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      html =
        live_view
        |> element("[phx-click='toggle-ai-panel']")
        |> render_click()

      assert html =~ "show me all users"
      assert html =~ "SELECT * FROM users;"
    end

    test "new-chat archives current and starts fresh", %{
      conn: conn,
      database: database,
      chat: chat
    } do
      {:ok, _} =
        Databases.create_chat_message(%{
          role: "user",
          content: "hello",
          database_id: database.id,
          chat_id: chat.id
        })

      {:ok, live_view, _html} = live(conn, ~p"/databases/#{database.id}/run")

      live_view
      |> element("[phx-click='toggle-ai-panel']")
      |> render_click()

      html =
        live_view
        |> element("[phx-click='new-chat']")
        |> render_click()

      assert html =~ "Ask me about your database"
      refute html =~ "hello"

      # Original chat is archived
      archived = Databases.list_archived_chats(database.id)
      assert length(archived) == 1
    end
  end

  describe "SQL action buttons" do
    test "renders Insert and Run buttons for SQL code blocks", %{
      conn: conn,
      database: database,
      chat: chat
    } do
      {:ok, _} =
        Databases.create_chat_message(%{
          role: "assistant",
          content: "Here you go:\n\n```sql\nSELECT * FROM users;\n```\n",
          database_id: database.id,
          chat_id: chat.id
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
      database: database,
      chat: chat
    } do
      {:ok, _} =
        Databases.create_chat_message(%{
          role: "assistant",
          content: "```sql\nSELECT * FROM users;\n```",
          database_id: database.id,
          chat_id: chat.id
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
    test "messages are stored in the database", %{database: database, chat: chat} do
      {:ok, msg} =
        Databases.create_chat_message(%{
          role: "user",
          content: "hello world",
          database_id: database.id,
          chat_id: chat.id
        })

      assert msg.role == "user"
      assert msg.content == "hello world"
      assert msg.database_id == database.id

      messages = Databases.list_chat_messages(chat.id)
      assert length(messages) == 1
      assert hd(messages).content == "hello world"
    end

    test "archive_chat archives and new chat starts empty", %{database: database, chat: chat} do
      for i <- 1..3 do
        Databases.create_chat_message(%{
          role: "user",
          content: "message #{i}",
          database_id: database.id,
          chat_id: chat.id
        })
      end

      assert length(Databases.list_chat_messages(chat.id)) == 3

      {:ok, archived} = Databases.archive_chat(chat.id)
      assert archived.archived_at != nil

      {:ok, new_chat} = Databases.get_or_create_active_chat(database.id)
      assert new_chat.id != chat.id
      assert Databases.list_chat_messages(new_chat.id) == []
    end

    test "messages are scoped to chat", %{database: database, chat: chat} do
      # Archive current chat and create a new one
      Databases.create_chat_message(%{
        role: "user",
        content: "for chat1",
        database_id: database.id,
        chat_id: chat.id
      })

      Databases.archive_chat(chat.id)
      {:ok, chat2} = Databases.get_or_create_active_chat(database.id)

      Databases.create_chat_message(%{
        role: "user",
        content: "for chat2",
        database_id: database.id,
        chat_id: chat2.id
      })

      chat1_messages = Databases.list_chat_messages(chat.id)
      chat2_messages = Databases.list_chat_messages(chat2.id)

      assert length(chat1_messages) == 1
      assert hd(chat1_messages).content == "for chat1"
      assert length(chat2_messages) == 1
      assert hd(chat2_messages).content == "for chat2"
    end

    test "rejects invalid role", %{database: database, chat: chat} do
      assert {:error, %Ecto.Changeset{valid?: false}} =
               Databases.create_chat_message(%{
                 role: "invalid",
                 content: "hello",
                 database_id: database.id,
                 chat_id: chat.id
               })
    end
  end

  describe "chat history" do
    test "list_archived_chats returns archived chats", %{database: database, chat: chat} do
      Databases.archive_chat(chat.id)
      {:ok, _new_chat} = Databases.get_or_create_active_chat(database.id)

      archived = Databases.list_archived_chats(database.id)
      assert length(archived) == 1
      assert hd(archived).id == chat.id
    end

    test "delete_chat removes an archived chat", %{database: database, chat: chat} do
      Databases.archive_chat(chat.id)
      {:ok, _} = Databases.delete_chat(chat.id)

      assert Databases.list_archived_chats(database.id) == []
    end
  end
end
