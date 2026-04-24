defmodule MelocotonWeb.DatabaseLive.Index do
  use MelocotonWeb, :live_view

  alias Melocoton.Databases
  alias Melocoton.Databases.{Database, Group}
  alias Melocoton.Settings

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    Databases.ensure_default_group()

    socket
    |> assign(:groups, Databases.list_groups())
    |> assign(:search_form, to_form(%{"term" => ""}))
    |> assign(:search_term, "")
    |> assign(:engine_filter, nil)
    |> assign(:data, %{})
    |> assign(:show_onboarding, not Melocoton.Settings.onboarding_completed?())
    |> reload_data()
    |> push_font_size()
    |> then(&{:ok, &1})
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("dismiss-onboarding", _params, socket) do
    Melocoton.Settings.complete_onboarding()

    socket
    |> assign(:show_onboarding, false)
    |> noreply()
  end

  @impl true
  def handle_event("show-onboarding", _params, socket) do
    Melocoton.Settings.reset_onboarding()

    socket
    |> assign(:show_onboarding, true)
    |> noreply()
  end

  @impl true
  def handle_event("validate-search", %{"term" => term}, socket) do
    socket
    |> assign(:search_term, term)
    |> reload_data()
    |> noreply()
  end

  @impl true
  def handle_event("filter-engine", %{"type" => type}, socket) do
    type = String.to_existing_atom(type)
    filter = if socket.assigns.engine_filter == type, do: nil, else: type

    socket
    |> assign(:engine_filter, filter)
    |> reload_data()
    |> noreply()
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    database = Databases.get_database!(id)
    {:ok, _} = Databases.delete_database(database)

    socket
    |> reload_data()
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("clone", %{"id" => id}, socket) do
    database = Databases.get_database!(id)

    case Databases.create_database(%{
           name: database.name <> " (copy)",
           type: database.type,
           url: database.url,
           group_id: database.group_id
         }) do
      {:ok, _clone} ->
        socket
        |> reload_data()
        |> put_flash(:info, gettext("Connection cloned"))
        |> then(&{:noreply, &1})

      {:error, _changeset} ->
        socket
        |> put_flash(:error, gettext("Failed to clone connection"))
        |> then(&{:noreply, &1})
    end
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
        Databases.save_test_result(database, :ok)

        socket
        |> reload_data()
        |> put_flash(:info, gettext("Connection successful"))
        |> then(&{:noreply, &1})

      {:error, reason} ->
        Logger.error("Error on connection: #{inspect(reason)}")
        Databases.save_test_result(database, :error)

        socket
        |> reload_data()
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
    |> reload_data()
    |> assign(:groups, Databases.list_groups())
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info({MelocotonWeb.OnboardingComponent, :onboarding_completed}, socket) do
    {:noreply, assign(socket, :show_onboarding, false)}
  end

  @impl true
  def handle_info({MelocotonWeb.SettingsModalComponent, :show_onboarding}, socket) do
    {:noreply, assign(socket, :show_onboarding, true)}
  end

  @impl true
  def handle_info({MelocotonWeb.GroupLive.FormComponent, {:saved, _group}}, socket) do
    socket
    |> reload_data()
    |> assign(:groups, Databases.list_groups())
    |> then(&{:noreply, &1})
  end

  defp reload_data(socket) do
    term = socket.assigns.search_term
    engine = socket.assigns.engine_filter

    databases =
      case term do
        t when t in [nil, ""] -> Databases.list_databases()
        t -> Databases.list_databases(t)
      end

    databases =
      case engine do
        nil -> databases
        type -> Enum.filter(databases, &(&1.type == type))
      end

    grouped = Enum.group_by(databases, & &1.group)
    groups = Databases.list_groups()
    empty = for g <- groups, not Map.has_key?(grouped, g), into: %{}, do: {g, []}

    assign(socket, :data, Map.merge(empty, grouped))
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

  defp push_font_size(socket) do
    if connected?(socket) do
      font_size = Settings.get("font_size") || "md"
      push_event(socket, "set-font-size", %{size: font_size})
    else
      socket
    end
  end
end
