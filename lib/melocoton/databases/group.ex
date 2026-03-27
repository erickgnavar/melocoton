defmodule Melocoton.Databases.Group do
  use Ecto.Schema
  import Ecto.Changeset

  schema "groups" do
    field :name, :string
    field :color, :string
    field :read_only, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :color, :read_only])
    |> validate_required([:name, :color])
  end
end
