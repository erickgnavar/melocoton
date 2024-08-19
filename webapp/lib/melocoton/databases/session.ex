defmodule Melocoton.Databases.Session do
  use Ecto.Schema
  import Ecto.Changeset

  alias Melocoton.Databases.Database

  schema "sessions" do
    field :query, :string
    belongs_to :database, Database

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:query, :database_id])
    |> validate_required([:database_id])
  end
end
