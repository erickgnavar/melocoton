defmodule Melocoton.Repo.Migrations.AddReadOnlyToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add :read_only, :boolean, default: false, null: false
    end
  end
end
