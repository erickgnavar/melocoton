defmodule MelocotonWeb.ShortcutsModal do
  use MelocotonWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(groups: Melocoton.Shortcuts.grouped())
    |> ok()
  end
end
