defmodule Melocoton.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :query, :text, null: true, default: ""
      add :database_id, references(:databases, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sessions, [:database_id])
  end
end
