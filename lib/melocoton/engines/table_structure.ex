defmodule Melocoton.Engines.TableStructure do
  @moduledoc """
  Represents the structure of a database table.
  """

  defstruct [
    :create_statement,
    columns: [],
    pk_columns: [],
    unique_constraints: [],
    foreign_keys: [],
    check_constraints: [],
    size: %{}
  ]

  @type column :: %{
          String.t() => String.t() | integer() | nil
        }

  @type foreign_key :: %{
          name: String.t(),
          column: String.t(),
          foreign_table: String.t(),
          foreign_column: String.t()
        }

  @type unique_constraint :: %{
          name: String.t(),
          columns: [String.t()]
        }

  @type check_constraint :: %{
          name: String.t(),
          definition: String.t()
        }

  @type t :: %__MODULE__{
          create_statement: String.t() | nil,
          columns: [column()],
          pk_columns: [String.t()],
          unique_constraints: [unique_constraint()],
          foreign_keys: [foreign_key()],
          check_constraints: [check_constraint()],
          size: map()
        }
end
