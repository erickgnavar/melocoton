defmodule MelocotonWeb.SqlLive.IndexExplorerComponent do
  use MelocotonWeb, :live_component
  alias Melocoton.DatabaseClient

  @impl true
  def update(%{repo: repo, index_name: name} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:result, DatabaseClient.get_index_definition(repo, name))
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col overflow-hidden" style="background: var(--bg-primary);">
      <div
        class="flex items-center px-3 py-1.5 text-[11px]"
        style="background: var(--bg-secondary); border-bottom: 1px solid var(--border-subtle);"
      >
        <.icon name="lucide-key-round" class="size-3 mr-1.5 text-amber-500" />
        <span style="color: var(--text-secondary);">{@index_name}</span>
        <span class="mx-1.5" style="color: var(--text-tertiary);">·</span>
        <span style="color: var(--text-tertiary);">on {@index_table}</span>
      </div>

      <div class="flex-1 overflow-auto p-3">
        <%= case @result do %>
          <% {:ok, definition} -> %>
            <.sql_block sql={definition} />
          <% {:error, err} -> %>
            <div class="text-xs text-red-500">{err}</div>
        <% end %>
      </div>
    </div>
    """
  end
end
