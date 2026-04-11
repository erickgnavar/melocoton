defmodule MelocotonWeb.SqlLive.SidebarComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import MelocotonWeb.SqlLive.SidebarComponents

  alias Phoenix.LiveView.AsyncResult

  describe "section/1" do
    test "renders title, count and items when the async result is loaded" do
      assigns = %{result: AsyncResult.ok(["alpha", "beta", "gamma"])}

      html =
        rendered_to_string(~H"""
        <.section :let={items} id="things" title="Things" assign={@result}>
          <span :for={item <- items} data-role="item">{item}</span>
        </.section>
        """)

      assert html =~ "Things"
      assert html =~ ~r/<span[^>]*>\s*3\s*<\/span>/
      assert html =~ ~s(data-role="item")
      assert html =~ "alpha"
      assert html =~ "beta"
      assert html =~ "gamma"
    end

    test "renders loading placeholder and no rows while loading" do
      assigns = %{result: AsyncResult.loading()}

      html =
        rendered_to_string(~H"""
        <.section :let={items} id="things" title="Things" assign={@result}>
          <span :for={item <- items} data-role="item">{item}</span>
        </.section>
        """)

      assert html =~ "Things"
      assert html =~ "..."
      refute html =~ ~s(data-role="item")
    end

    test "renders error marker when async result failed" do
      assigns = %{result: AsyncResult.failed(AsyncResult.loading(), "boom")}

      html =
        rendered_to_string(~H"""
        <.section :let={items} id="things" title="Things" assign={@result}>
          <span :for={item <- items} data-role="item">{item}</span>
        </.section>
        """)

      assert html =~ "err"
      refute html =~ ~s(data-role="item")
    end

    test "defaults to collapsed (hidden content, closed chevron visible)" do
      assigns = %{result: AsyncResult.ok([1, 2])}

      html =
        rendered_to_string(~H"""
        <.section :let={_items} id="things" title="Things" assign={@result}>
          <span>body</span>
        </.section>
        """)

      assert html =~ ~s(id="things-content")
      # content wrapper is hidden by default
      assert html =~ ~r/id="things-content"[^>]*class="[^"]*hidden/
      # closed chevron visible (no hidden class), open chevron hidden
      assert html =~ ~r/id="things-chevron-open"[^>]*class="[^"]*hidden/
      refute html =~ ~r/id="things-chevron-closed"[^>]*class="[^"]*hidden/
    end

    test "open=true flips chevron and un-hides content" do
      assigns = %{result: AsyncResult.ok([1, 2])}

      html =
        rendered_to_string(~H"""
        <.section :let={_items} id="things" title="Things" assign={@result} open>
          <span>body</span>
        </.section>
        """)

      refute html =~ ~r/id="things-content"[^>]*class="[^"]*hidden/
      refute html =~ ~r/id="things-chevron-open"[^>]*class="[^"]*hidden/
      assert html =~ ~r/id="things-chevron-closed"[^>]*class="[^"]*hidden/
    end

    test "uses the id to namespace toggle targets" do
      assigns = %{result: AsyncResult.ok([])}

      html =
        rendered_to_string(~H"""
        <.section :let={_items} id="widgets" title="Widgets" assign={@result}>
          <span>body</span>
        </.section>
        """)

      assert html =~ ~s(id="widgets-content")
      assert html =~ ~s(id="widgets-chevron-open")
      assert html =~ ~s(id="widgets-chevron-closed")
      assert html =~ "#widgets-content"
      assert html =~ "#widgets-chevron-open"
      assert html =~ "#widgets-chevron-closed"
    end
  end
end
