defmodule Melocoton.Databases.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  alias Melocoton.Databases.{ChatMessage, Database}

  schema "chats" do
    field :title, :string
    field :archived_at, :utc_datetime

    belongs_to :database, Database
    has_many :messages, ChatMessage

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:title, :archived_at, :database_id])
    |> validate_required([:database_id])
  end
end
