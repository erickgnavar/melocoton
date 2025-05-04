defmodule Melocoton.DatabasesTest do
  use Melocoton.DataCase

  alias Melocoton.Databases

  describe "databases" do
    alias Melocoton.Databases.Database

    import Melocoton.DatabasesFixtures

    @invalid_attrs %{name: nil, type: nil, url: nil}

    test "list_databases/0 returns all databases" do
      database = database_fixture() |> Melocoton.Repo.preload(:group)
      assert Databases.list_databases() == [database]
    end

    test "get_database!/1 returns the database with given id" do
      database = database_fixture() |> Melocoton.Repo.preload(:sessions)
      assert Databases.get_database!(database.id) == database
    end

    test "create_database/1 with valid data creates a database" do
      valid_attrs = %{name: "some name", type: "sqlite", url: "some url"}

      assert {:ok, %Database{} = database} = Databases.create_database(valid_attrs)
      assert database.name == "some name"
      assert database.type == :sqlite
      assert database.url == "some url"
    end

    test "create_database/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Databases.create_database(@invalid_attrs)
    end

    test "update_database/2 with valid data updates the database" do
      database = database_fixture()

      update_attrs = %{
        name: "some updated name",
        type: "postgres",
        url: "some updated url"
      }

      assert {:ok, %Database{} = database} = Databases.update_database(database, update_attrs)
      assert database.name == "some updated name"
      assert database.type == :postgres
      assert database.url == "some updated url"
    end

    test "update_database/2 with invalid data returns error changeset" do
      database = database_fixture() |> Melocoton.Repo.preload(:sessions)
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

  describe "groups" do
    alias Melocoton.Databases.Group

    import Melocoton.DatabasesFixtures

    @invalid_attrs %{name: nil, color: nil}

    test "list_groups/0 returns all groups" do
      group = group_fixture()
      assert Databases.list_groups() == [group]
    end

    test "get_group!/1 returns the group with given id" do
      group = group_fixture()
      assert Databases.get_group!(group.id) == group
    end

    test "create_group/1 with valid data creates a group" do
      valid_attrs = %{name: "some name", color: "some color"}

      assert {:ok, %Group{} = group} = Databases.create_group(valid_attrs)
      assert group.name == "some name"
      assert group.color == "some color"
    end

    test "create_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Databases.create_group(@invalid_attrs)
    end

    test "update_group/2 with valid data updates the group" do
      group = group_fixture()
      update_attrs = %{name: "some updated name", color: "some updated color"}

      assert {:ok, %Group{} = group} = Databases.update_group(group, update_attrs)
      assert group.name == "some updated name"
      assert group.color == "some updated color"
    end

    test "update_group/2 with invalid data returns error changeset" do
      group = group_fixture()
      assert {:error, %Ecto.Changeset{}} = Databases.update_group(group, @invalid_attrs)
      assert group == Databases.get_group!(group.id)
    end

    test "delete_group/1 deletes the group" do
      group = group_fixture()
      assert {:ok, %Group{}} = Databases.delete_group(group)
      assert_raise Ecto.NoResultsError, fn -> Databases.get_group!(group.id) end
    end

    test "change_group/1 returns a group changeset" do
      group = group_fixture()
      assert %Ecto.Changeset{} = Databases.change_group(group)
    end
  end
end
