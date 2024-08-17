defmodule Melocoton.Databases.Database do
  use Ecto.Schema
  import Ecto.Changeset

  schema "databases" do
    field :name, :string
    field :type, :string
    field :url, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(database, attrs) do
    database
    |> cast(attrs, [:name, :type, :url])
    |> validate_required([:name, :type, :url])
  end
end
