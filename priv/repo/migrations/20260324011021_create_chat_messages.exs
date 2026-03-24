defmodule Melocoton.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :role, :string, null: false
      add :content, :text, null: false
      add :database_id, references(:databases, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:database_id])
  end
end
