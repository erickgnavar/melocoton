defmodule Melocoton.DatabasesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Melocoton.Databases` context.
  """

  @doc """
  Generate a database.
  """
  def database_fixture(attrs \\ %{}) do
    {:ok, database} =
      attrs
      |> Enum.into(%{
        name: "some name",
        type: :sqlite,
        url: "some url"
      })
      |> Melocoton.Databases.create_database()

    database
  end

  @doc """
  Generate a group.
  """
  def group_fixture(attrs \\ %{}) do
    {:ok, group} =
      attrs
      |> Enum.into(%{
        color: "some color",
        name: "some name"
      })
      |> Melocoton.Databases.create_group()

    group
  end
end
