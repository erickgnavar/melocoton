defmodule MelocotonWeb.SqlLive.SqlEditorComponent do
  use MelocotonWeb, :live_component
  alias Melocoton.Databases

  @impl true
  def update(%{session: session} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:form, to_form(Databases.change_session(session, %{})))
    |> assign_new(:editor_theme_light, fn ->
      Melocoton.Settings.get("editor_theme_light") || "default"
    end)
    |> assign_new(:editor_theme_dark, fn ->
      Melocoton.Settings.get("editor_theme_dark") || "oneDark"
    end)
    |> ok()
  end
end
