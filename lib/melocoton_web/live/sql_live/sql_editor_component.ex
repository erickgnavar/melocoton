defmodule MelocotonWeb.SqlLive.SqlEditorComponent do
  use MelocotonWeb, :live_component
  alias Melocoton.Databases

  @impl true
  def update(%{session: session} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:form, to_form(Databases.change_session(session, %{})))
    |> ok()
  end
end
