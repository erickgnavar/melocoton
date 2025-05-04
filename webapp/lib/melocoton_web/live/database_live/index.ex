defmodule MelocotonWeb.DatabaseLive.Index do
  use MelocotonWeb, :live_view

  alias Melocoton.Databases
  alias Melocoton.Databases.{Database, Group}

  @impl true
  def mount(_params, _session, socket) do
    groups = Databases.list_groups()

    socket
    |> assign(:groups, groups)
    |> assign(:databases, Databases.list_databases())
    |> then(&{:ok, &1})
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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
    {:noreply, assign(socket, :databases, Databases.list_databases())}
  end

  @impl true
  def handle_info({MelocotonWeb.GroupLive.FormComponent, {:saved, _group}}, socket) do
    {:noreply, assign(socket, :databases, Databases.list_databases())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    database = Databases.get_database!(id)
    {:ok, _} = Databases.delete_database(database)

    {:noreply, assign(socket, :databases, Databases.list_databases())}
  end
end
