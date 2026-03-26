defmodule MelocotonWeb.CommandPaletteTest do
  use MelocotonWeb.ConnCase

  import Phoenix.LiveViewTest
  import Melocoton.DatabasesFixtures

  setup do
    group1 = group_fixture(%{name: "Production", color: "#ff0000"})
    group2 = group_fixture(%{name: "Staging", color: "#00ff00"})

    db1 = database_fixture(%{name: "Users DB", group_id: group1.id})
    db2 = database_fixture(%{name: "Analytics", group_id: group1.id})
    db3 = database_fixture(%{name: "Staging App", group_id: group2.id})

    %{databases: [db1, db2, db3], groups: [group1, group2]}
  end

  describe "open/close" do
    test "palette starts closed", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      assert has_element?(view, "#command-palette")
      refute has_element?(view, "#command-palette-input")
    end

    test "opens via open-command-palette event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      assert has_element?(view, "#command-palette-input")
    end

    test "lists all databases when opened", %{conn: conn, databases: [db1, db2, db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      assert has_element?(view, "#command-palette-item-#{db1.id}")
      assert has_element?(view, "#command-palette-item-#{db2.id}")
      assert has_element?(view, "#command-palette-item-#{db3.id}")
    end

    test "closes via Escape key", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})
      assert has_element?(view, "#command-palette-input")

      send_navigate_key(view, "Escape")

      refute has_element?(view, "#command-palette-input")
    end
  end

  describe "search/filtering" do
    test "filters databases by name", %{conn: conn, databases: [db1, db2, db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_search(view, "Users")

      assert has_element?(view, "#command-palette-item-#{db1.id}")
      refute has_element?(view, "#command-palette-item-#{db2.id}")
      refute has_element?(view, "#command-palette-item-#{db3.id}")
    end

    test "filters databases by group name", %{conn: conn, databases: [db1, db2, db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_search(view, "Staging")

      assert has_element?(view, "#command-palette-item-#{db3.id}")
      refute has_element?(view, "#command-palette-item-#{db1.id}")
      refute has_element?(view, "#command-palette-item-#{db2.id}")
    end

    test "fuzzy matches by subsequence", %{conn: conn, databases: [db1, db2, db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      # "udb" matches "Users DB" as subsequence (u...d...b)
      send_search(view, "udb")

      assert has_element?(view, "#command-palette-item-#{db1.id}")
      refute has_element?(view, "#command-palette-item-#{db2.id}")
      refute has_element?(view, "#command-palette-item-#{db3.id}")
    end

    test "shows no results message when nothing matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_search(view, "zzzznonexistent")

      assert render(view) =~ "No databases found"
    end

    test "search is case insensitive", %{conn: conn, databases: [db1, _db2, _db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_search(view, "users db")

      assert has_element?(view, "#command-palette-item-#{db1.id}")
    end

    test "empty search shows all databases", %{conn: conn, databases: [db1, db2, db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_search(view, "Users")
      refute has_element?(view, "#command-palette-item-#{db2.id}")

      send_search(view, "")

      assert has_element?(view, "#command-palette-item-#{db1.id}")
      assert has_element?(view, "#command-palette-item-#{db2.id}")
      assert has_element?(view, "#command-palette-item-#{db3.id}")
    end
  end

  describe "keyboard navigation" do
    test "ArrowDown does not go past last item", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      for _ <- 1..10 do
        send_navigate_key(view, "ArrowDown")
      end

      # Should still render without error
      assert has_element?(view, "#command-palette-input")
    end

    test "ArrowUp does not go below zero", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_navigate_key(view, "ArrowUp")

      assert has_element?(view, "#command-palette-input")
    end

    test "Enter navigates to first database by default", %{conn: conn, databases: [db1, _, _]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_navigate_key(view, "Enter")

      assert_redirect(view, ~p"/databases/#{db1.id}/run")
    end

    test "Enter navigates to correct database after ArrowDown",
         %{conn: conn, databases: [_db1, db2, _db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_navigate_key(view, "ArrowDown")
      send_navigate_key(view, "Enter")

      assert_redirect(view, ~p"/databases/#{db2.id}/run")
    end

    test "Ctrl+N moves selection down", %{conn: conn, databases: [_db1, db2, _db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_navigate_key(view, "n", %{"ctrlKey" => true})
      send_navigate_key(view, "Enter")

      assert_redirect(view, ~p"/databases/#{db2.id}/run")
    end

    test "Ctrl+P moves selection up", %{conn: conn, databases: [db1, _db2, _db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_navigate_key(view, "ArrowDown")
      send_navigate_key(view, "p", %{"ctrlKey" => true})
      send_navigate_key(view, "Enter")

      assert_redirect(view, ~p"/databases/#{db1.id}/run")
    end

    test "search resets selection index", %{conn: conn, databases: [_db1, _db2, db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      send_navigate_key(view, "ArrowDown")
      send_navigate_key(view, "ArrowDown")

      # Search narrows to one result, index resets to 0
      send_search(view, "Staging App")
      send_navigate_key(view, "Enter")

      assert_redirect(view, ~p"/databases/#{db3.id}/run")
    end
  end

  describe "click selection" do
    test "clicking a database navigates to it", %{conn: conn, databases: [db1, _db2, _db3]} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      view
      |> element("#command-palette-item-#{db1.id}")
      |> render_click()

      assert_redirect(view, ~p"/databases/#{db1.id}/run")
    end
  end

  describe "display" do
    test "shows group name badges", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      html = view |> element("#command-palette-results") |> render()
      assert html =~ "Production"
      assert html =~ "Staging"
    end

    test "shows database type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      render_hook(view, "open-command-palette", %{})

      html = view |> element("#command-palette-results") |> render()
      assert html =~ "sqlite"
    end
  end

  defp send_search(view, query) do
    view
    |> element("#command-palette form")
    |> render_change(%{"query" => query})
  end

  defp send_navigate_key(view, key, extra \\ %{}) do
    view
    |> element("#command-palette-input")
    |> render_keydown(Map.merge(%{"key" => key}, extra))
  end
end
