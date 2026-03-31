defmodule MelocotonWeb.CommandPalette do
  use MelocotonWeb, :live_component

  alias Melocoton.Databases

  @actions [
    %{id: :home, name: "Home", icon: "lucide-home", action: "navigate-home"},
    %{
      id: :export_csv,
      name: "Export to CSV",
      icon: "lucide-file-spreadsheet",
      action: "export-csv"
    },
    %{
      id: :export_xlsx,
      name: "Export to Excel",
      icon: "lucide-file-spreadsheet",
      action: "export-xlsx"
    },
    %{id: :settings, name: "Settings", icon: "lucide-settings", action: "open-settings"},
    %{
      id: :shortcuts,
      name: "Keyboard Shortcuts",
      icon: "lucide-keyboard",
      action: "show-shortcuts"
    }
  ]

  @impl true
  def update(%{action: :open}, socket) do
    items = build_items()

    socket
    |> assign(open: true, query: "", filtered: items, selected_index: 0, items: items)
    |> ok()
  end

  def update(assigns, socket) do
    if socket.assigns[:items] do
      socket |> assign(assigns) |> ok()
    else
      items = build_items()

      socket
      |> assign(assigns)
      |> assign(items: items, filtered: items, query: "", selected_index: 0, open: false)
      |> ok()
    end
  end

  defp build_items do
    databases = Databases.list_databases() |> Enum.map(&Map.put(&1, :kind, :database))
    actions = Enum.map(@actions, &Map.put(&1, :kind, :action))
    databases ++ actions
  end

  @impl true
  def handle_event("close", _params, socket) do
    socket
    |> assign(open: false)
    |> push_event("refocus-editor", %{})
    |> noreply()
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    filtered = fuzzy_filter(socket.assigns.items, query)

    socket
    |> assign(query: query, filtered: filtered, selected_index: 0)
    |> noreply()
  end

  @impl true
  def handle_event("navigate", %{"key" => "ArrowDown"}, socket) do
    max = length(socket.assigns.filtered) - 1
    index = min(socket.assigns.selected_index + 1, max)

    socket
    |> assign(selected_index: index)
    |> noreply()
  end

  @impl true
  def handle_event("navigate", %{"key" => "ArrowUp"}, socket) do
    index = max(socket.assigns.selected_index - 1, 0)

    socket
    |> assign(selected_index: index)
    |> noreply()
  end

  # Ctrl+N = down
  def handle_event("navigate", %{"key" => "n", "ctrlKey" => true}, socket) do
    handle_event("navigate", %{"key" => "ArrowDown"}, socket)
  end

  # Ctrl+P = up
  def handle_event("navigate", %{"key" => "p", "ctrlKey" => true}, socket) do
    handle_event("navigate", %{"key" => "ArrowUp"}, socket)
  end

  @impl true
  def handle_event("navigate", %{"key" => "Escape"}, socket) do
    socket
    |> assign(open: false)
    |> push_event("refocus-editor", %{})
    |> noreply()
  end

  @impl true
  def handle_event("navigate", %{"key" => "Enter"}, socket) do
    select_current(socket)
  end

  def handle_event("navigate", _params, socket), do: noreply(socket)

  # Prevent form submission (Enter is handled by navigate keydown)
  def handle_event("do-nothing", _params, socket), do: noreply(socket)

  @impl true
  def handle_event("select-current", _params, socket) do
    select_current(socket)
  end

  @impl true
  def handle_event("select", %{"type" => "database", "id" => id}, socket) do
    navigate_to_database(socket, id)
  end

  def handle_event("select", %{"type" => "action", "action" => action}, socket) do
    execute_action(socket, action)
  end

  defp select_current(socket) do
    case Enum.at(socket.assigns.filtered, socket.assigns.selected_index) do
      nil -> noreply(socket)
      %{kind: :database} = db -> navigate_to_database(socket, db.id)
      %{kind: :action} = action -> execute_action(socket, action.action)
    end
  end

  defp navigate_to_database(socket, id) do
    socket
    |> assign(open: false)
    |> push_navigate(to: ~p"/databases/#{id}/run")
    |> noreply()
  end

  defp execute_action(socket, "navigate-home") do
    socket
    |> assign(open: false)
    |> push_navigate(to: ~p"/databases")
    |> noreply()
  end

  defp execute_action(socket, action) do
    notify_parent({:palette_action, action})

    socket
    |> assign(open: false)
    |> noreply()
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp fuzzy_filter(items, "") do
    items
  end

  defp fuzzy_filter(items, query) do
    query_down = String.downcase(query)

    Enum.filter(items, fn
      %{kind: :database} = db ->
        fuzzy_match?(String.downcase(db.name), query_down) or
          fuzzy_match?(String.downcase(db.group.name), query_down)

      %{kind: :action} = action ->
        fuzzy_match?(String.downcase(action.name), query_down)
    end)
  end

  defp fuzzy_match?(string, query) do
    String.contains?(string, query) or subsequence_match?(string, query)
  end

  defp subsequence_match?(string, query) do
    string_chars = String.graphemes(string)
    query_chars = String.graphemes(query)
    do_subsequence_match(string_chars, query_chars)
  end

  defp do_subsequence_match(_string, []), do: true
  defp do_subsequence_match([], _query), do: false

  defp do_subsequence_match([s | s_rest], [q | q_rest] = query) do
    if s == q do
      do_subsequence_match(s_rest, q_rest)
    else
      do_subsequence_match(s_rest, query)
    end
  end
end
