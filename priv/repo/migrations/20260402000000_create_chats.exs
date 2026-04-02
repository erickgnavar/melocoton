defmodule Melocoton.Repo.Migrations.CreateChats do
  use Ecto.Migration

  def change do
    create table(:chats) do
      add :title, :string
      add :archived_at, :utc_datetime
      add :database_id, references(:databases, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chats, [:database_id])

    alter table(:chat_messages) do
      add :chat_id, references(:chats, on_delete: :delete_all)
    end

    create index(:chat_messages, [:chat_id])

    # Backfill: create one chat per database that has messages, then link messages
    execute(
      """
      INSERT INTO chats (database_id, title, inserted_at, updated_at)
      SELECT DISTINCT database_id, 'Previous conversation', datetime('now'), datetime('now')
      FROM chat_messages
      """,
      ""
    )

    execute(
      """
      UPDATE chat_messages
      SET chat_id = (
        SELECT chats.id FROM chats
        WHERE chats.database_id = chat_messages.database_id
        LIMIT 1
      )
      WHERE chat_id IS NULL
      """,
      ""
    )
  end
end
