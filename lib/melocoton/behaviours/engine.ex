defmodule Melocoton.Behaviours.Engine do
  @moduledoc """
  Set of specs to be implemented by a database engine
  """

  alias Melocoton.Databases.Database

  @typep repo :: atom
  @typep index :: %{name: String.t(), table: String.t()}

  @doc """
  Return all the existing tables and columns inside the given
  repo connection
  """
  @callback get_tables(repo) :: {:ok, [map]} | {:error, String.t()}

  @doc """
  Return all the existing indexes inside the given repo connection
  """
  @callback get_indexes(repo) :: {:ok, [index]} | {:error, String.t()}

  @doc """
  Validate if we can connect with the received database
  """
  @callback test_connection(Database.t()) :: :ok | {:error, String.t()}
end
