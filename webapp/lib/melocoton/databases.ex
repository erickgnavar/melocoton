defmodule Melocoton.Databases do
  @moduledoc """
  The Databases context.
  """

  import Ecto.Query, warn: false
  alias Melocoton.Repo

  alias Melocoton.Databases.{Database, Session}

  @doc """
  Returns the list of databases.

  ## Examples

      iex> list_databases()
      [%Database{}, ...]

  """
  def list_databases do
    Database
    |> preload(:group)
    |> Repo.all()
  end

  def list_databases(term) do
    term = String.downcase("%#{term}%")

    query =
      from database in Database,
        where: like(fragment("LOWER(?)", database.name), ^term),
        preload: [:group]

    Repo.all(query)
  end

  @doc """
  Gets a single database.

  Raises `Ecto.NoResultsError` if the Database does not exist.

  ## Examples

      iex> get_database!(123)
      %Database{}

      iex> get_database!(456)
      ** (Ecto.NoResultsError)

  """
  def get_database!(id), do: Repo.get!(Database, id) |> Repo.preload([:group, :sessions])

  @doc """
  Creates a database.

  ## Examples

      iex> create_database(%{field: value})
      {:ok, %Database{}}

      iex> create_database(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_database(attrs \\ %{}) do
    %Database{}
    |> Database.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a database.

  ## Examples

      iex> update_database(database, %{field: new_value})
      {:ok, %Database{}}

      iex> update_database(database, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_database(%Database{} = database, attrs) do
    database
    |> Database.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a database.

  ## Examples

      iex> delete_database(database)
      {:ok, %Database{}}

      iex> delete_database(database)
      {:error, %Ecto.Changeset{}}

  """
  def delete_database(%Database{} = database) do
    Repo.delete(database)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking database changes.

  ## Examples

      iex> change_database(database)
      %Ecto.Changeset{data: %Database{}}

  """
  def change_database(%Database{} = database, attrs \\ %{}) do
    Database.changeset(database, attrs)
  end

  @doc """
  Creates a session.

  ## Examples

      iex> create_session(%{field: value})
      {:ok, %Database{}}

      iex> create_session(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_session(attrs \\ %{}) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a session.

  ## Examples

      iex> update_session(session, %{field: new_value})
      {:ok, %Session{}}

      iex> update_session(session, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session changes.

  ## Examples

      iex> change_session(session)
      %Ecto.Changeset{data: %Session{}}

  """
  def change_session(%Session{} = session, attrs \\ %{}) do
    Session.changeset(session, attrs)
  end

  alias Melocoton.Databases.Group

  @doc """
  Returns the list of groups.

  ## Examples

      iex> list_groups()
      [%Group{}, ...]

  """
  def list_groups do
    Repo.all(Group)
  end

  @doc """
  Gets a single group.

  Raises `Ecto.NoResultsError` if the Group does not exist.

  ## Examples

      iex> get_group!(123)
      %Group{}

      iex> get_group!(456)
      ** (Ecto.NoResultsError)

  """
  def get_group!(id), do: Repo.get!(Group, id)

  @doc """
  Creates a group.

  ## Examples

      iex> create_group(%{field: value})
      {:ok, %Group{}}

      iex> create_group(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_group(attrs \\ %{}) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a group.

  ## Examples

      iex> update_group(group, %{field: new_value})
      {:ok, %Group{}}

      iex> update_group(group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a group.

  ## Examples

      iex> delete_group(group)
      {:ok, %Group{}}

      iex> delete_group(group)
      {:error, %Ecto.Changeset{}}

  """
  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.

  ## Examples

      iex> change_group(group)
      %Ecto.Changeset{data: %Group{}}

  """
  def change_group(%Group{} = group, attrs \\ %{}) do
    Group.changeset(group, attrs)
  end
end
