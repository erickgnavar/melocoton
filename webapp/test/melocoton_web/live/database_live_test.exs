defmodule MelocotonWeb.DatabaseLiveTest do
  use MelocotonWeb.ConnCase

  import Phoenix.LiveViewTest
  import Melocoton.DatabasesFixtures

  @create_attrs %{name: "some name", type: "sqlite", url: "some url"}
  @update_attrs %{name: "some updated name", type: "postgres", url: "some updated url"}
  @invalid_attrs %{name: nil, type: nil, url: nil}

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

      assert index_live |> element("a", "New Database") |> render_click() =~
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

      assert index_live |> element("#databases-#{database.id} a", "Edit") |> render_click() =~
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

      assert index_live |> element("#databases-#{database.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#databases-#{database.id}")
    end
  end

  describe "Show" do
    setup [:create_database]

    test "displays database", %{conn: conn, database: database} do
      {:ok, _show_live, html} = live(conn, ~p"/databases/#{database}")

      assert html =~ "Show Database"
      assert html =~ database.name
    end

    test "updates database within modal", %{conn: conn, database: database} do
      {:ok, show_live, _html} = live(conn, ~p"/databases/#{database}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Database"

      assert_patch(show_live, ~p"/databases/#{database}/show/edit")

      assert show_live
             |> form("#database-form", database: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#database-form", database: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/databases/#{database}")

      html = render(show_live)
      assert html =~ "Database updated successfully"
      assert html =~ "some updated name"
    end
  end
end
