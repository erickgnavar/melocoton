defmodule Melocoton.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :key, :string, null: false
      add :value, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:settings, [:key])
  end
end
