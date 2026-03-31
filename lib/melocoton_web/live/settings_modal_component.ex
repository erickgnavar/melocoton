defmodule MelocotonWeb.SettingsModalComponent do
  use MelocotonWeb, :live_component

  alias Melocoton.AI.Models
  alias Melocoton.Settings

  @presets %{"xs" => 11, "sm" => 12, "md" => 14, "lg" => 16, "xl" => 18}

  @impl true
  def update(assigns, socket) do
    settings = Settings.get_api_key_settings()
    font_size = Settings.get("font_size") || "md"
    {provider, model} = Models.parse_model_string(settings["ai_model"])

    socket
    |> assign(assigns)
    |> assign(
      settings: settings,
      saved: false,
      font_size: font_size,
      font_size_px: font_size_to_px(font_size),
      provider: provider,
      model: model,
      model_options: Models.model_options(provider),
      required_key: Models.required_api_key(provider)
    )
    |> ok()
  end

  @impl true
  def handle_event("set-font-size", %{"size" => size}, socket) do
    apply_font_size(socket, size)
  end

  @impl true
  def handle_event("set-font-size-px", %{"font_size_px" => px_str}, socket) do
    case Integer.parse(px_str) do
      {px, _} when px >= 8 and px <= 24 ->
        preset = Enum.find_value(@presets, fn {k, v} -> if v == px, do: k end)
        size = preset || to_string(px)
        apply_font_size(socket, size)

      _ ->
        noreply(socket)
    end
  end

  @impl true
  def handle_event("set-font-size-px", _params, socket), do: noreply(socket)

  @impl true
  def handle_event("change-provider", %{"provider" => provider}, socket) do
    model_options = Models.model_options(provider)

    first_model =
      case model_options do
        [{_, id} | _] -> id
        [] -> nil
      end

    socket
    |> assign(
      provider: provider,
      model: first_model,
      model_options: model_options,
      required_key: Models.required_api_key(provider)
    )
    |> noreply()
  end

  @impl true
  def handle_event("change-model", %{"model" => model}, socket) do
    socket |> assign(model: model) |> noreply()
  end

  @impl true
  def handle_event("save-settings", params, socket) do
    ai_model = Models.build_model_string(socket.assigns.provider, socket.assigns.model)
    params = if ai_model, do: Map.put(params, "ai_model", ai_model), else: params

    Settings.save_api_key_settings(params)
    settings = Settings.get_api_key_settings()
    {provider, model} = Models.parse_model_string(settings["ai_model"])

    socket
    |> assign(
      saved: true,
      settings: settings,
      provider: provider,
      model: model,
      model_options: Models.model_options(provider)
    )
    |> noreply()
  end

  defp apply_font_size(socket, size) do
    Settings.set("font_size", size)

    socket
    |> assign(font_size: size, font_size_px: font_size_to_px(size))
    |> push_event("set-font-size", %{size: size})
    |> noreply()
  end

  defp font_size_to_px(size) do
    Map.get(@presets, size) || parse_custom_px(size)
  end

  defp parse_custom_px(size) do
    case Integer.parse(size) do
      {px, _} -> px
      :error -> 14
    end
  end

  defp mask_key(nil), do: ""
  defp mask_key(""), do: ""

  defp mask_key(key) when byte_size(key) > 8 do
    String.slice(key, 0, 4) <> String.duplicate("*", 12) <> String.slice(key, -4, 4)
  end

  defp mask_key(key), do: String.duplicate("*", String.length(key))
end
