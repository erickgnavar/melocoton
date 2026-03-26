defmodule MelocotonWeb.CommandPalette do
  use MelocotonWeb, :live_component

  alias Melocoton.Databases

  @impl true
  def update(%{action: :open}, socket) do
    databases = Databases.list_databases()

    socket
    |> assign(open: true, query: "", filtered: databases, selected_index: 0, databases: databases)
    |> ok()
  end

  def update(assigns, socket) do
    if socket.assigns[:databases] do
      socket |> assign(assigns) |> ok()
    else
      databases = Databases.list_databases()

      socket
      |> assign(assigns)
      |> assign(
        databases: databases,
        filtered: databases,
        query: "",
        selected_index: 0,
        open: false
      )
      |> ok()
    end
  end

  @impl true
  def handle_event("close", _params, socket) do
    socket
    |> assign(open: false)
    |> noreply()
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    filtered = fuzzy_filter(socket.assigns.databases, query)

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
    |> noreply()
  end

  @impl true
  def handle_event("navigate", %{"key" => "Enter"}, socket) do
    select_current(socket)
  end

  def handle_event("navigate", _params, socket), do: noreply(socket)

  @impl true
  def handle_event("select-current", _params, socket) do
    select_current(socket)
  end

  @impl true
  def handle_event("select", %{"id" => id}, socket) do
    socket
    |> assign(open: false)
    |> push_navigate(to: ~p"/databases/#{id}/run")
    |> noreply()
  end

  defp select_current(socket) do
    case Enum.at(socket.assigns.filtered, socket.assigns.selected_index) do
      nil ->
        noreply(socket)

      db ->
        socket
        |> assign(open: false)
        |> push_navigate(to: ~p"/databases/#{db.id}/run")
        |> noreply()
    end
  end

  defp fuzzy_filter(databases, "") do
    databases
  end

  defp fuzzy_filter(databases, query) do
    query_down = String.downcase(query)

    databases
    |> Enum.filter(fn db ->
      name_down = String.downcase(db.name)
      group_down = String.downcase(db.group.name)
      fuzzy_match?(name_down, query_down) or fuzzy_match?(group_down, query_down)
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
