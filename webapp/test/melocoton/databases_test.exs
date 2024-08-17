defmodule Melocoton.DatabasesTest do
  use Melocoton.DataCase

  alias Melocoton.Databases

  describe "databases" do
    alias Melocoton.Databases.Database

    import Melocoton.DatabasesFixtures

    @invalid_attrs %{name: nil, type: nil, url: nil}

    test "list_databases/0 returns all databases" do
      database = database_fixture()
      assert Databases.list_databases() == [database]
    end

    test "get_database!/1 returns the database with given id" do
      database = database_fixture()
      assert Databases.get_database!(database.id) == database
    end

    test "create_database/1 with valid data creates a database" do
      valid_attrs = %{name: "some name", type: "some type", url: "some url"}

      assert {:ok, %Database{} = database} = Databases.create_database(valid_attrs)
      assert database.name == "some name"
      assert database.type == "some type"
      assert database.url == "some url"
    end

    test "create_database/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Databases.create_database(@invalid_attrs)
    end

    test "update_database/2 with valid data updates the database" do
      database = database_fixture()

      update_attrs = %{
        name: "some updated name",
        type: "some updated type",
        url: "some updated url"
      }

      assert {:ok, %Database{} = database} = Databases.update_database(database, update_attrs)
      assert database.name == "some updated name"
      assert database.type == "some updated type"
      assert database.url == "some updated url"
    end

    test "update_database/2 with invalid data returns error changeset" do
      database = database_fixture()
      assert {:error, %Ecto.Changeset{}} = Databases.update_database(database, @invalid_attrs)
      assert database == Databases.get_database!(database.id)
    end

    test "delete_database/1 deletes the database" do
      database = database_fixture()
      assert {:ok, %Database{}} = Databases.delete_database(database)
      assert_raise Ecto.NoResultsError, fn -> Databases.get_database!(database.id) end
    end

    test "change_database/1 returns a database changeset" do
      database = database_fixture()
      assert %Ecto.Changeset{} = Databases.change_database(database)
    end
  end
end
