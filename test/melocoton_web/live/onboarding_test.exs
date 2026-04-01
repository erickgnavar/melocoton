defmodule MelocotonWeb.OnboardingTest do
  use MelocotonWeb.ConnCase

  import Phoenix.LiveViewTest
  import Melocoton.DatabasesFixtures

  alias Melocoton.Settings

  setup do
    Settings.delete("onboarding_completed")
    database_fixture()
    :ok
  end

  describe "first-use display" do
    test "shows onboarding modal on first visit", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/databases")

      assert html =~ "Welcome to Melocoton"
      assert has_element?(view, "#onboarding-modal")
    end

    test "does not show onboarding when already completed", %{conn: conn} do
      Settings.set("onboarding_completed", "true")

      {:ok, _view, html} = live(conn, ~p"/databases")

      refute html =~ "Welcome to Melocoton"
    end
  end

  describe "step navigation" do
    test "advances to next step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      assert render(view) =~ "Welcome to Melocoton"

      click_next(view)

      assert render(view) =~ "Connections"
      assert render(view) =~ "connection URL"
    end

    test "goes back to previous step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      click_next(view)
      assert render(view) =~ "Connections"

      view |> element("button", "Back") |> render_click()
      assert render(view) =~ "Welcome to Melocoton"
    end

    test "back button is hidden on first step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      refute has_element?(view, "#onboarding-wrapper button", "Back")
    end

    test "walks through all steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      expected_content = [
        "Welcome to Melocoton",
        "Connections",
        "Groups",
        "SQL Workspace",
        "AI Assistant",
        "Keyboard-First"
      ]

      for {content, i} <- Enum.with_index(expected_content) do
        assert render(view) =~ content, "Step #{i} should contain '#{content}'"

        if i < length(expected_content) - 1 do
          click_next(view)
        end
      end
    end
  end

  describe "completion" do
    test "completing last step saves setting and hides modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      # Navigate to last step
      for _ <- 1..5, do: click_next(view)
      assert render(view) =~ "Keyboard-First"

      # Click "Get Started" on last step
      view |> element("button", "Get Started") |> render_click()

      refute has_element?(view, "#onboarding-modal")
      assert Settings.get("onboarding_completed") == "true"
    end

    test "skip saves setting and hides modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      view |> element("button", "Skip") |> render_click()

      refute has_element?(view, "#onboarding-modal")
      assert Settings.get("onboarding_completed") == "true"
    end

    test "dismiss via cancel saves setting and hides modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      assert has_element?(view, "#onboarding-modal")

      render_hook(view, "dismiss-onboarding", %{})

      refute has_element?(view, "#onboarding-modal")
      assert Settings.get("onboarding_completed") == "true"
    end
  end

  describe "re-trigger" do
    test "show-onboarding event re-shows the tutorial", %{conn: conn} do
      Settings.set("onboarding_completed", "true")

      {:ok, view, _html} = live(conn, ~p"/databases")
      refute has_element?(view, "#onboarding-modal")

      render_hook(view, "show-onboarding", %{})

      assert has_element?(view, "#onboarding-modal")
      assert render(view) =~ "Welcome to Melocoton"
      assert is_nil(Settings.get("onboarding_completed"))
    end
  end

  describe "step content" do
    test "step 0 shows engine badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/databases")

      assert html =~ "PostgreSQL"
      assert html =~ "MySQL"
      assert html =~ "SQLite"
    end

    test "groups step mentions read-only", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      for _ <- 1..2, do: click_next(view)

      html = render(view)
      assert html =~ "read-only"
      assert html =~ "INSERT, UPDATE, DELETE, DROP"
    end

    test "AI step shows toggle shortcut", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      for _ <- 1..4, do: click_next(view)

      html = render(view)
      assert html =~ "AI Assistant"
      assert html =~ "Toggle AI panel"
    end

    test "keyboard step shows shortcut keys", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      for _ <- 1..5, do: click_next(view)

      html = render(view)
      assert html =~ "Command palette"
      assert html =~ "Keyboard shortcuts"
      assert html =~ "Settings"
    end

    test "last step shows Get Started button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/databases")

      for _ <- 1..5, do: click_next(view)

      assert render(view) =~ "Get Started"
    end

    test "non-last steps show Next button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/databases")

      assert html =~ "Next"
      refute html =~ "Get Started"
    end
  end

  defp click_next(view) do
    view |> element("#onboarding-wrapper button[phx-click='next-step']") |> render_click()
  end
end
