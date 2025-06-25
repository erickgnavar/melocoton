defmodule MelocotonWeb.SqlLive.TableExplorerComponent do
  use MelocotonWeb, :live_component
  alias Melocoton.DatabaseClient

  @initial_limit 20

  @impl true
  def update(%{repo: repo, table_name: table_name} = assigns, socket) do
    page = 1
    pages = 1..get_num_pages(repo, table_name, @initial_limit)

    socket
    |> assign(assigns)
    |> assign(limit: @initial_limit, page: page, pages: Enum.to_list(pages))
    |> assign(:limit_form, to_form(%{"limit" => @initial_limit}))
    |> assign_async(:result, fn -> get_result(repo, table_name, page, @initial_limit) end)
    |> ok()
  end

  @impl true
  def handle_event("go-back", _params, socket) do
    notify_parent(:reset_table_explorer)
    {:noreply, socket}
  end

  @impl true
  def handle_event("previous-page", _params, socket) do
    page = (socket.assigns.page == 1 && 1) || socket.assigns.page - 1
    %{repo: repo, table_name: table_name, limit: limit} = socket.assigns

    socket
    |> assign(:page, page)
    |> assign_async(:result, fn -> get_result(repo, table_name, page, limit) end)
    |> noreply()
  end

  @impl true
  def handle_event("next-page", _params, socket) do
    page =
      (socket.assigns.page == length(socket.assigns.pages) && socket.assigns.page) ||
        socket.assigns.page + 1

    %{repo: repo, table_name: table_name, limit: limit} = socket.assigns

    socket
    |> assign(:page, page)
    |> assign_async(:result, fn -> get_result(repo, table_name, page, limit) end)
    |> noreply()
  end

  @impl true
  def handle_event("change-page", %{"page" => page}, socket) do
    {page, _} = Integer.parse(page)
    %{repo: repo, table_name: table_name, limit: limit} = socket.assigns

    socket
    |> assign(page: page)
    |> assign_async(:result, fn -> get_result(repo, table_name, page, limit) end)
    |> noreply()
  end

  @impl true
  def handle_event("validate-limit", %{"limit" => limit}, socket) do
    {limit, _} = Integer.parse(limit)
    %{repo: repo, table_name: table_name, page: page} = socket.assigns

    socket
    |> assign(limit: limit)
    |> assign_async(:result, fn -> get_result(repo, table_name, page, limit) end)
    |> noreply()
  end

  defp get_num_pages(repo, table_name, limit) do
    # we need to add an alias so we can have the same result in
    # postgres and sqlite, otherwise the column name will be different
    # and we need to handle more case clauses
    case DatabaseClient.query(repo, "SELECT COUNT(*) AS count FROM #{table_name}") do
      {:ok, %{rows: [%{"count" => count}]}, _} ->
        div(count, limit) + 1

      {:error, _error} ->
        1
    end
  end

  defp get_result(repo, table_name, page, limit) do
    offset = (page - 1) * limit
    sql = "SELECT * FROM #{table_name} LIMIT #{limit} OFFSET #{offset}"

    case DatabaseClient.query(repo, sql) do
      {:ok, result, _} ->
        {:ok, %{result: result}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
