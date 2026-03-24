defmodule MelocotonWeb.SettingsModalComponent do
  use MelocotonWeb, :live_component

  alias Melocoton.Settings

  @impl true
  def update(assigns, socket) do
    settings = Settings.get_api_key_settings()

    socket
    |> assign(assigns)
    |> assign(
      settings: settings,
      saved: false,
      current_model: Application.get_env(:melocoton, :ai)[:model] || ""
    )
    |> ok()
  end

  @impl true
  def handle_event("save-settings", params, socket) do
    Settings.save_api_key_settings(params)

    socket
    |> assign(
      saved: true,
      settings: Settings.get_api_key_settings(),
      current_model: Application.get_env(:melocoton, :ai)[:model] || ""
    )
    |> noreply()
  end

  @impl true
  def handle_event("close-settings", _params, socket) do
    notify_parent(:close_settings)
    noreply(socket)
  end

  defp mask_key(nil), do: ""
  defp mask_key(""), do: ""

  defp mask_key(key) when byte_size(key) > 8 do
    String.slice(key, 0, 4) <> String.duplicate("*", 12) <> String.slice(key, -4, 4)
  end

  defp mask_key(key), do: String.duplicate("*", String.length(key))

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
