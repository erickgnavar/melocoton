defmodule Melocoton.Repo.Migrations.CreateDatabases do
  use Ecto.Migration

  def change do
    create table(:databases) do
      add :name, :string, null: false
      add :type, :string, null: false
      add :url, :string, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
