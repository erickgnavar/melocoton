defmodule Melocoton.Behaviours.Engine do
  @moduledoc """
  Set of specs to be implemented by a database engine
  """

  alias Melocoton.Databases.Database
  alias Melocoton.Engines.{TableMeta, TableStructure}

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
  Return the structure of a table: columns, constraints, foreign keys, etc.
  """
  @callback get_table_structure(repo, String.t()) ::
              {:ok, TableStructure.t()} | {:error, String.t()}

  @doc """
  Return column names and primary key columns for a table.
  """
  @callback get_table_meta(repo, String.t()) :: TableMeta.t()

  @doc """
  Return an estimated row count for a table, used for pagination.
  Falls back to exact count when estimates are unavailable.
  """
  @callback get_estimated_count(repo, String.t()) :: non_neg_integer()

  @doc """
  Return all foreign key relations across the entire database.
  """
  @callback get_all_relations(repo) :: {:ok, [map]} | {:error, String.t()}

  @doc """
  Validate if we can connect with the received database
  """
  @callback test_connection(Database.t()) :: :ok | {:error, String.t()}
end
