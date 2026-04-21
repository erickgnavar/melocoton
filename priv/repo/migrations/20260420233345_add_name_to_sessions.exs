defmodule Melocoton.Repo.Migrations.AddNameToSessions do
  use Ecto.Migration

  def up do
    alter table(:sessions) do
      add :name, :string, null: false, default: "query_1.sql"
    end

    execute("""
    UPDATE sessions
    SET name = (
      SELECT '#' || COUNT(*)
      FROM sessions s2
      WHERE s2.database_id = sessions.database_id
        AND (s2.inserted_at < sessions.inserted_at
             OR (s2.inserted_at = sessions.inserted_at AND s2.id <= sessions.id))
    )
    """)
  end

  def down do
    alter table(:sessions) do
      remove :name
    end
  end
end
