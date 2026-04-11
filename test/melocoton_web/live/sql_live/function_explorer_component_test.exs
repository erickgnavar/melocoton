defmodule MelocotonWeb.SqlLive.FunctionExplorerComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MelocotonWeb.SqlLive.FunctionExplorerComponent

  defp base_assigns(overrides) do
    %{
      database: %{group: %{color: "#ff6600"}},
      function_name: "add_ints",
      function_kind: "function"
    }
    |> Map.merge(overrides)
  end

  describe "render/1" do
    test "shows the function name and kind in the header" do
      html =
        base_assigns(%{result: {:ok, "CREATE FUNCTION add_ints ..."}})
        |> FunctionExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "add_ints"
      assert html =~ "function"
      assert html =~ "lucide-function-square"
      assert html =~ "#ff6600"
    end

    test "renders the definition via sql_block when the result is ok" do
      html =
        base_assigns(%{result: {:ok, "SELECT 1 + 1"}})
        |> FunctionExplorerComponent.render()
        |> rendered_to_string()

      # sql_block wraps in the shared ai-sql-block container
      assert html =~ "ai-sql-block"
      # MDEx emits a <pre><code> block from the fenced SQL
      assert html =~ "<pre"
      assert html =~ "<code"
      refute html =~ "text-red-500"
    end

    test "renders an error message when the result is an error" do
      html =
        base_assigns(%{result: {:error, "Function not found"}})
        |> FunctionExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Function not found"
      assert html =~ "text-red-500"
      refute html =~ "ai-sql-block"
    end

    test "renders procedure kind label" do
      html =
        base_assigns(%{function_kind: "procedure", result: {:ok, "CREATE PROCEDURE ..."}})
        |> FunctionExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "procedure"
    end
  end
end
