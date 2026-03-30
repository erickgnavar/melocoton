defmodule MelocotonWeb.DatabaseLive.Index do
  use MelocotonWeb, :live_view

  alias Melocoton.Databases
  alias Melocoton.Databases.{Database, Group}

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:groups, Databases.list_groups())
    |> assign(:data, get_grouped_databases())
    |> assign(:search_form, to_form(%{"term" => ""}))
    |> assign(:search_term, "")
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
    |> assign(:search_term, term)
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

  @impl true
  def handle_event("test-connection", %{"id" => id}, socket) do
    database = Databases.get_database!(id)

    engine =
      case database.type do
        :sqlite -> Melocoton.Engines.Sqlite
        :postgres -> Melocoton.Engines.Postgres
        :mysql -> Melocoton.Engines.Mysql
      end

    case engine.test_connection(database) do
      :ok ->
        socket
        |> put_flash(:info, gettext("Connection successful"))
        |> then(&{:noreply, &1})

      {:error, reason} ->
        Logger.error("Error on connection: #{inspect(reason)}")

        socket
        |> put_flash(
          :error,
          gettext("Error on connection: %{reason}", %{reason: "#{inspect(reason)}"})
        )
        |> then(&{:noreply, &1})
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Database")
    |> assign(:database, Databases.get_database!(id))
  end

  defp apply_action(socket, :new, params) do
    socket
    |> assign(:page_title, "New Database")
    |> assign(:database, %Database{group_id: params["group_id"]})
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
    grouped = Enum.group_by(Databases.list_databases(), & &1.group)

    empty_groups =
      for g <- Databases.list_groups(), not Map.has_key?(grouped, g), into: %{}, do: {g, []}

    Map.merge(empty_groups, grouped)
  end

  defp get_grouped_databases(term) do
    grouped = Enum.group_by(Databases.list_databases(term), & &1.group)

    empty_groups =
      for g <- Databases.list_groups(), not Map.has_key?(grouped, g), into: %{}, do: {g, []}

    Map.merge(empty_groups, grouped)
  end

  defp time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 2_592_000 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end
end
