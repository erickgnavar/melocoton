defmodule MelocotonWeb.SqlLive.IndexExplorerComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MelocotonWeb.SqlLive.IndexExplorerComponent

  defp base_assigns(overrides) do
    %{
      database: %{group: %{color: "#22cc66"}},
      index_name: "users_email_idx",
      index_table: "users"
    }
    |> Map.merge(overrides)
  end

  describe "render/1" do
    test "shows the index name and target table in the header" do
      html =
        base_assigns(%{result: {:ok, "CREATE INDEX users_email_idx ON users (email)"}})
        |> IndexExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "users_email_idx"
      assert html =~ "on users"
      assert html =~ "lucide-key-round"
    end

    test "renders the definition via sql_block when the result is ok" do
      html =
        base_assigns(%{result: {:ok, "CREATE INDEX users_email_idx ON users (email)"}})
        |> IndexExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "ai-sql-block"
      assert html =~ "<pre"
      assert html =~ "<code"
      refute html =~ "text-red-500"
    end

    test "renders an error message when the result is an error" do
      html =
        base_assigns(%{result: {:error, "Index not found"}})
        |> IndexExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "Index not found"
      assert html =~ "text-red-500"
      refute html =~ "ai-sql-block"
    end

    test "renders unique index definition" do
      html =
        base_assigns(%{result: {:ok, "CREATE UNIQUE INDEX users_email_idx ON users (email)"}})
        |> IndexExplorerComponent.render()
        |> rendered_to_string()

      assert html =~ "keyword-modifier"
      assert html =~ "ai-sql-block"
    end
  end
end
