defmodule MelocotonWeb.SqlLive.TriggerExplorerComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MelocotonWeb.SqlLive.TriggerExplorerComponent

  defp base_assigns(overrides) do
    %{
      database: %{group: %{color: "#22cc66"}},
      trigger_name: "users_noop",
      trigger_table: "users"
    }
    |> Map.merge(overrides)
  end

  describe "render/1" do
    test "shows the trigger name and target table in the header" do
      html =
        base_assigns(%{result: {:ok, "CREATE TRIGGER users_noop ..."}})
        |> TriggerExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "users_noop"
      assert html =~ "on users"
      assert html =~ "lucide-zap"
      assert html =~ "#22cc66"
    end

    test "renders the definition via sql_block when the result is ok" do
      html =
        base_assigns(%{result: {:ok, "CREATE TRIGGER users_noop BEFORE INSERT ON users"}})
        |> TriggerExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "ai-sql-block"
      assert html =~ "<pre"
      assert html =~ "<code"
      refute html =~ "text-red-500"
    end

    test "renders an error message when the result is an error" do
      html =
        base_assigns(%{result: {:error, "Trigger not found"}})
        |> TriggerExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Trigger not found"
      assert html =~ "text-red-500"
      refute html =~ "ai-sql-block"
    end
  end
end
