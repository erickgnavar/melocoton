defmodule Melocoton.Databases.Database do
  use Ecto.Schema
  import Ecto.Changeset

  alias Melocoton.Databases.{Group, Session}

  @postgres_regex ~r/^postgres(?:ql)?:\/\/(?:([^:@]+)(?::([^@]*))?@)?([^:\/]+)(?::(\d+))?\/([^?]+)(?:\?(.+))?$/
  @mysql_regex ~r/^mysql:\/\/(?:([^:@]+)(?::([^@]*))?@)?([^:\/]+)(?::(\d+))?\/([^?]+)(?:\?(.+))?$/
  @sqlite_regex ~r/^\/(?:[^\/\0]+\/?)*$/

  schema "databases" do
    field :name, :string
    field :type, Ecto.Enum, values: [:sqlite, :postgres, :mysql], default: :sqlite
    field :url, :string
    field :last_connected_at, :utc_datetime

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

      :mysql ->
        if Regex.match?(@mysql_regex, url) do
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

  def show_public_url(%{type: :mysql, url: url}), do: mask_url_password(url)
  def show_public_url(%{type: :postgres, url: url}), do: mask_url_password(url)

  defp mask_url_password(url) do
    parsed = URI.parse(url)

    case parsed.userinfo do
      nil ->
        url

      userinfo ->
        user = userinfo |> String.split(":", parts: 2) |> hd()
        parsed |> Map.put(:userinfo, "#{user}:***") |> URI.to_string()
    end
  end
end
