defmodule MelocotonWeb.DatabaseLive.Index do
  use MelocotonWeb, :live_view

  alias Melocoton.Databases
  alias Melocoton.Databases.{Database, Group}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:groups, Databases.list_groups())
    |> assign(:data, get_grouped_databases())
    |> assign(:search_form, to_form(%{"term" => ""}))
    |> then(&{:ok, &1})
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("validate-search", %{"term" => term}, socket) do
    socket
    |> assign(:data, get_grouped_databases(term))
    |> noreply()
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    database = Databases.get_database!(id)
    {:ok, _} = Databases.delete_database(database)

    socket
    |> assign(:data, get_grouped_databases())
    |> then(&{:noreply, &1})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Database")
    |> assign(:database, Databases.get_database!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Database")
    |> assign(:database, %Database{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Databases")
    |> assign(:database, nil)
  end

  defp apply_action(socket, :edit_group, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Group")
    |> assign(:group, Databases.get_group!(id))
  end

  defp apply_action(socket, :new_group, _params) do
    socket
    |> assign(:page_title, "New Group")
    |> assign(:group, %Group{})
  end

  @impl true
  def handle_info({MelocotonWeb.DatabaseLive.FormComponent, {:saved, _database}}, socket) do
    socket
    |> assign(:data, get_grouped_databases())
    |> assign(:groups, Databases.list_groups())
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info({MelocotonWeb.GroupLive.FormComponent, {:saved, _group}}, socket) do
    socket
    |> assign(:data, get_grouped_databases())
    |> assign(:groups, Databases.list_groups())
    |> then(&{:noreply, &1})
  end

  defp get_grouped_databases(term \\ nil)

  defp get_grouped_databases(nil) do
    Enum.group_by(Databases.list_databases(), & &1.group)
  end

  defp get_grouped_databases(term) do
    Enum.group_by(Databases.list_databases(term), & &1.group)
  end
end
