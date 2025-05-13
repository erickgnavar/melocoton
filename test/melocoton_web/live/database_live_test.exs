defmodule MelocotonWeb.DatabaseLiveTest do
  use MelocotonWeb.ConnCase

  import Phoenix.LiveViewTest
  import Melocoton.DatabasesFixtures

  @create_attrs %{name: "some name", type: "sqlite", url: "some url"}
  @update_attrs %{name: "some updated name", type: "postgres", url: "some updated url"}
  @invalid_attrs %{name: nil, type: :sqlite, url: nil}

  defp create_database(_) do
    database = database_fixture()
    %{database: database}
  end

  describe "Index" do
    setup [:create_database]

    test "lists all databases", %{conn: conn, database: database} do
      {:ok, _index_live, html} = live(conn, ~p"/databases")

      assert html =~ "Listing Databases"
      assert html =~ database.name
    end

    test "saves new database", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")

      assert index_live |> element("a", "New Connection") |> render_click() =~
               "New Database"

      assert_patch(index_live, ~p"/databases/new")

      assert index_live
             |> form("#database-form", database: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#database-form", database: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/databases")

      html = render(index_live)
      assert html =~ "Database created successfully"
      assert html =~ "some name"
    end

    test "updates database in listing", %{conn: conn, database: database} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")

      assert index_live |> element("#databases-#{database.id} a[title='Edit']") |> render_click() =~
               "Edit Database"

      assert_patch(index_live, ~p"/databases/#{database}/edit")

      assert index_live
             |> form("#database-form", database: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#database-form", database: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/databases")

      html = render(index_live)
      assert html =~ "Database updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes database in listing", %{conn: conn, database: database} do
      {:ok, index_live, _html} = live(conn, ~p"/databases")

      assert index_live
             |> element("#databases-#{database.id} a[title='Delete']")
             |> render_click()

      refute has_element?(index_live, "#databases-#{database.id}")
    end
  end
end
