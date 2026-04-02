defmodule Melocoton.Databases.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Melocoton.Databases.{Chat, Database}

  schema "chat_messages" do
    field :role, :string
    field :content, :string
    belongs_to :database, Database
    belongs_to :chat, Chat

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:role, :content, :database_id, :chat_id])
    |> validate_required([:role, :content, :database_id])
    |> validate_inclusion(:role, ["user", "assistant"])
  end
end
