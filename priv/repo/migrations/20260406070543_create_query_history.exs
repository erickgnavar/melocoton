defmodule Melocoton.Repo.Migrations.CreateQueryHistory do
  use Ecto.Migration

  def change do
    create table(:query_history) do
      add :query, :text, null: false
      add :database_id, references(:databases, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "success"
      add :row_count, :integer, default: 0
      add :execution_time, :integer, default: 0
      add :error_message, :text
      add :executed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:query_history, [:database_id])
    create index(:query_history, [:executed_at])
  end
end
