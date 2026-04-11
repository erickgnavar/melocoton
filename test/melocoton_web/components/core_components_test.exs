defmodule MelocotonWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import MelocotonWeb.CoreComponents

  describe "sql_block/1" do
    test "wraps SQL in the shared ai-sql-block container" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sql_block sql="SELECT 1" />
        """)

      assert html =~ ~s(class="ai-sql-block rounded overflow-hidden text-xs")
    end

    test "renders the SQL content through MDEx (tokens are highlighted)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sql_block sql="SELECT id FROM users" />
        """)

      # MDEx wraps code fences in <pre><code>...
      assert html =~ "<pre"
      assert html =~ "<code"
      # Identifiers from the SQL still appear in the output
      assert html =~ "SELECT"
      assert html =~ "users"
    end

    test "accepts a custom class override" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.sql_block sql="SELECT 1" class="text-[10px]" />
        """)

      assert html =~ ~s(class="ai-sql-block rounded overflow-hidden text-[10px]")
      refute html =~ "text-xs"
    end
  end
end
