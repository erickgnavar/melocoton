defmodule Melocoton.Repo.Migrations.AddTestStatusToDatabases do
  use Ecto.Migration

  def change do
    alter table(:databases) do
      add :last_test_status, :string
      add :last_tested_at, :utc_datetime
    end
  end
end
