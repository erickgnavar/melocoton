defmodule MelocotonWeb.ShortcutsModal do
  use MelocotonWeb, :live_component

  alias Melocoton.Shortcuts

  @impl true
  def update(assigns, socket) do
    groups =
      Shortcuts.contexts()
      |> Enum.map(fn ctx ->
        %{
          label: Shortcuts.context_label(ctx),
          shortcuts: Shortcuts.for_context(ctx)
        }
      end)

    socket
    |> assign(assigns)
    |> assign(groups: groups)
    |> ok()
  end
end
