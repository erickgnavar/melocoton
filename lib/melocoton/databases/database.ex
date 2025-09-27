defmodule Melocoton.Databases.Database do
  use Ecto.Schema
  import Ecto.Changeset

  alias Melocoton.Databases.{Group, Session}

  @postgres_regex ~r/^postgres(?:ql)?:\/\/(?:([^:@]+)(?::([^@]*))?@)?([^:\/]+)(?::(\d+))?\/([^?]+)(?:\?(.+))?$/
  @sqlite_regex ~r/^\/(?:[^\/\0]+\/?)*$/

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
    |> validate_url()
  end

  defp validate_url(%{valid?: false} = changeset), do: changeset

  defp validate_url(changeset) do
    url = get_field(changeset, :url)

    changeset
    |> get_field(:type)
    |> case do
      :postgres ->
        if Regex.match?(@postgres_regex, url) do
          changeset
        else
          add_error(changeset, :url, "Invalid connection string")
        end

      :sqlite ->
        if Regex.match?(@sqlite_regex, url) do
          changeset
        else
          add_error(changeset, :url, "Invalid connection string")
        end
    end
  end

  def show_public_url(%{type: :sqlite, url: url}), do: url

  def show_public_url(%{type: :postgres, url: url}) do
    [user, _pass] = url |> URI.parse() |> Map.get(:userinfo) |> String.split(":")

    url
    |> URI.parse()
    |> Map.put(:userinfo, "#{user}:***")
    |> URI.to_string()
  end
end
