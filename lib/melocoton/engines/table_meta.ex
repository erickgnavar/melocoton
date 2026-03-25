defmodule Melocoton.Engines.TableMeta do
  @moduledoc """
  Lightweight metadata about a database table: column names and primary key columns.
  """

  defstruct columns: [], pk_columns: [], column_types: %{}

  @type t :: %__MODULE__{
          columns: [String.t()],
          pk_columns: [String.t()],
          column_types: %{String.t() => String.t()}
        }
end
