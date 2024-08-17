defmodule MelocotonWeb.DatabaseControllerTest do
  use MelocotonWeb.ConnCase

  import Melocoton.DatabasesFixtures

  @create_attrs %{name: "some name", type: "some type", url: "some url"}
  @update_attrs %{name: "some updated name", type: "some updated type", url: "some updated url"}
  @invalid_attrs %{name: nil, type: nil, url: nil}

  describe "index" do
    test "lists all databases", %{conn: conn} do
      conn = get(conn, ~p"/databases")
      assert html_response(conn, 200) =~ "Listing Databases"
    end
  end

  describe "new database" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/databases/new")
      assert html_response(conn, 200) =~ "New Database"
    end
  end

  describe "create database" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/databases", database: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/databases/#{id}"

      conn = get(conn, ~p"/databases/#{id}")
      assert html_response(conn, 200) =~ "Database #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/databases", database: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Database"
    end
  end

  describe "edit database" do
    setup [:create_database]

    test "renders form for editing chosen database", %{conn: conn, database: database} do
      conn = get(conn, ~p"/databases/#{database}/edit")
      assert html_response(conn, 200) =~ "Edit Database"
    end
  end

  describe "update database" do
    setup [:create_database]

    test "redirects when data is valid", %{conn: conn, database: database} do
      conn = put(conn, ~p"/databases/#{database}", database: @update_attrs)
      assert redirected_to(conn) == ~p"/databases/#{database}"

      conn = get(conn, ~p"/databases/#{database}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, database: database} do
      conn = put(conn, ~p"/databases/#{database}", database: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Database"
    end
  end

  describe "delete database" do
    setup [:create_database]

    test "deletes chosen database", %{conn: conn, database: database} do
      conn = delete(conn, ~p"/databases/#{database}")
      assert redirected_to(conn) == ~p"/databases"

      assert_error_sent 404, fn ->
        get(conn, ~p"/databases/#{database}")
      end
    end
  end

  defp create_database(_) do
    database = database_fixture()
    %{database: database}
  end
end
