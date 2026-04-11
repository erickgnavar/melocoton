defmodule MelocotonWeb.SqlLive.SidebarComponents do
  @moduledoc """
  Function components used by the SQLLive.Run left sidebar.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  import MelocotonWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a collapsible sidebar section backed by an async assign.

  Handles the header (title, count, chevron), the toggle wiring, the
  async_result loading/failed slots, and the collapsed-by-default
  content wrapper. The caller provides the row rendering via the
  default slot, which receives the unwrapped item list as a `:let`.

  ## Example

      <.section id="indexes" title="Indexes" assign={@indexes} :let={indexes}>
        <div :for={idx <- indexes}>{idx.name}</div>
      </.section>
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :assign, :any, required: true, doc: "an async_result assign"
  attr :open, :boolean, default: false

  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <div class="p-2 app-section-border">
      <div
        class="flex items-center justify-between cursor-pointer"
        phx-click={
          JS.toggle(to: "##{@id}-content")
          |> JS.toggle(to: "##{@id}-chevron-open")
          |> JS.toggle(to: "##{@id}-chevron-closed")
        }
      >
        <div
          class="text-[11px] font-medium uppercase tracking-wide"
          style="color: var(--text-secondary);"
        >
          {@title}
        </div>
        <div class="flex items-center gap-1.5">
          <.async_result :let={items} assign={@assign}>
            <:loading>
              <span class="text-[10px]" style="color: var(--text-tertiary);">...</span>
            </:loading>
            <:failed :let={_failure}>
              <span class="text-[10px] text-red-500">err</span>
            </:failed>
            <span class="text-[10px]" style="color: var(--text-tertiary);">
              {length(items)}
            </span>
          </.async_result>
          <span id={"#{@id}-chevron-open"} class={if !@open, do: "hidden"}>
            <.icon name="lucide-chevron-down" class="size-3" style="color: var(--text-tertiary);" />
          </span>
          <span id={"#{@id}-chevron-closed"} class={if @open, do: "hidden"}>
            <.icon name="lucide-chevron-right" class="size-3" style="color: var(--text-tertiary);" />
          </span>
        </div>
      </div>
      <div id={"#{@id}-content"} class={["mt-1 text-xs", if(!@open, do: "hidden")]}>
        <.async_result :let={items} assign={@assign}>
          <:loading></:loading>
          <:failed :let={failure}>{"#{inspect(failure)}"}</:failed>
          {render_slot(@inner_block, items)}
        </.async_result>
      </div>
    </div>
    """
  end
end
