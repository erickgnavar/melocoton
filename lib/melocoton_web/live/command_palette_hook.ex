defmodule MelocotonWeb.CommandPaletteHook do
  @moduledoc """
  on_mount hook that adds command palette support to all LiveViews.
  Attaches a handle_event for "open-command-palette" that triggers
  the command palette component via send_update.
  """

  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    socket = attach_hook(socket, :command_palette_event, :handle_event, &handle_event/3)
    {:cont, socket}
  end

  defp handle_event("open-command-palette", _params, socket) do
    send_update(MelocotonWeb.CommandPalette, id: "command-palette", action: :open)
    {:halt, socket}
  end

  defp handle_event(_event, _params, socket) do
    {:cont, socket}
  end
end
