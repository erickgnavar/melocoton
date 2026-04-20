defmodule Melocoton.Behaviours.Engine do
  @moduledoc """
  Set of specs to be implemented by a database engine
  """

  alias Melocoton.Databases.Database
  alias Melocoton.Engines.{TableMeta, TableStructure}

  @typep repo :: atom
  @typep index :: %{name: String.t(), table: String.t()}
  @typep function_summary :: %{
           id: String.t(),
           name: String.t(),
           schema: String.t() | nil,
           kind: :function | :procedure,
           return_type: String.t() | nil,
           arguments: String.t() | nil,
           language: String.t() | nil
         }
  @typep trigger_summary :: %{
           id: String.t(),
           name: String.t(),
           table: String.t()
         }

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
  Return all user-defined functions and stored procedures in the database.
  """
  @callback get_functions(repo) :: {:ok, [function_summary]} | {:error, String.t()}

  @doc """
  Return the full definition (source/DDL) of a function or stored procedure,
  identified by the engine-specific id returned by `get_functions/1`.
  """
  @callback get_function_definition(repo, String.t()) ::
              {:ok, String.t()} | {:error, String.t()}

  @doc """
  Return all user-defined triggers in the database.
  """
  @callback get_triggers(repo) :: {:ok, [trigger_summary]} | {:error, String.t()}

  @doc """
  Return the full definition (source/DDL) of a trigger, identified by the
  engine-specific id returned by `get_triggers/1`.
  """
  @callback get_trigger_definition(repo, String.t()) ::
              {:ok, String.t()} | {:error, String.t()}

  @doc """
  Return the full definition (DDL) of an index, identified by its name.
  """
  @callback get_index_definition(repo, String.t()) ::
              {:ok, String.t()} | {:error, String.t()}

  @doc """
  Validate if we can connect with the received database
  """
  @callback test_connection(Database.t()) :: :ok | {:error, String.t()}
end
