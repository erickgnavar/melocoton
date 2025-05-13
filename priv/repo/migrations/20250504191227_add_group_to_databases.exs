defmodule Melocoton.Repo.Migrations.AddGroupToDatabases do
  use Ecto.Migration

  def change do
    alter table(:databases) do
      add :group_id, references(:groups, on_delete: :delete_all), null: true
    end

    create index(:databases, [:group_id])
  end
end
