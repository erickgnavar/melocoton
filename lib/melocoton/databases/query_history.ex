defmodule Melocoton.Databases.QueryHistory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Melocoton.Databases.Database

  schema "query_history" do
    field :query, :string
    field :status, Ecto.Enum, values: [:success, :error], default: :success
    field :row_count, :integer, default: 0
    field :execution_time, :integer, default: 0
    field :error_message, :string
    field :executed_at, :utc_datetime

    belongs_to :database, Database

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :query,
      :database_id,
      :status,
      :row_count,
      :execution_time,
      :error_message,
      :executed_at
    ])
    |> validate_required([:query, :database_id, :executed_at])
  end
end
