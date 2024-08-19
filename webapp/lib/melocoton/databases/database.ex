defmodule Melocoton.Databases.Database do
  use Ecto.Schema
  import Ecto.Changeset

  alias Melocoton.Databases.Session

  schema "databases" do
    field :name, :string
    field :type, Ecto.Enum, values: [:sqlite, :postgres], default: :sqlite
    field :url, :string

    has_many :sessions, Session

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(database, attrs) do
    database
    |> cast(attrs, [:name, :type, :url])
    |> validate_required([:name, :type, :url])
  end
end
