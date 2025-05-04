defmodule Melocoton.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups) do
      add :name, :string, null: true
      add :color, :string, null: true

      timestamps(type: :utc_datetime)
    end
  end
end
