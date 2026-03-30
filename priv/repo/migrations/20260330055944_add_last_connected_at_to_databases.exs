defmodule Melocoton.Repo.Migrations.AddLastConnectedAtToDatabases do
  use Ecto.Migration

  def change do
    alter table(:databases) do
      add :last_connected_at, :utc_datetime
    end
  end
end
