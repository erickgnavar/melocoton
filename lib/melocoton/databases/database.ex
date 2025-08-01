defmodule Melocoton.Databases.Database do
  use Ecto.Schema
  import Ecto.Changeset

  alias Melocoton.Databases.{Group, Session}

  schema "databases" do
    field :name, :string
    field :type, Ecto.Enum, values: [:sqlite, :postgres], default: :sqlite
    field :url, :string

    belongs_to :group, Group
    has_many :sessions, Session

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(database, attrs) do
    database
    |> cast(attrs, [:name, :type, :url, :group_id])
    |> validate_required([:name, :type, :url])
  end
end
