defmodule MelocotonWeb.GroupLive.FormComponent do
  use MelocotonWeb, :live_component

  alias Melocoton.Databases

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <.simple_form
        for={@form}
        id="group-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:color]} type="color" label="Color" style="height: 100px" />

        <div class="mt-4 p-3 border border-app-border-light dark:border-app-border-dark rounded bg-app-sidebar-light dark:bg-app-sidebar-dark dark-transition">
          <div class="text-xs font-medium mb-1">Preview:</div>
          <div class="flex items-center p-1">
            <span
              id="name-preview"
              class="font-medium"
              style={"color: " <> (@form.params["color"] || "")}
            >
              {@form.params["name"]}
            </span>
          </div>
        </div>
        <:actions>
          <.button phx-disable-with="Saving...">Save Group</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{group: group} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Databases.change_group(group))
     end)}
  end

  @impl true
  def handle_event("validate", %{"group" => group_params}, socket) do
    changeset = Databases.change_group(socket.assigns.group, group_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"group" => group_params}, socket) do
    save_group(socket, socket.assigns.action, group_params)
  end

  defp save_group(socket, :edit_group, group_params) do
    case Databases.update_group(socket.assigns.group, group_params) do
      {:ok, group} ->
        notify_parent({:saved, group})

        {:noreply,
         socket
         |> put_flash(:info, "Group updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_group(socket, :new_group, group_params) do
    case Databases.create_group(group_params) do
      {:ok, group} ->
        notify_parent({:saved, group})

        {:noreply,
         socket
         |> put_flash(:info, "Group created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
