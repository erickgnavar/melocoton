defmodule MelocotonWeb.SqlLive.AiChatComponent do
  use MelocotonWeb, :live_component

  alias Melocoton.{AI, Databases}

  @impl true
  def update(%{ai_response: {ref, result}}, socket) do
    socket
    |> handle_ai_response(ref, result)
    |> ok()
  end

  def update(assigns, socket) do
    if socket.assigns[:database_id] && socket.assigns.database_id == assigns.database.id do
      # Same database — preserve state, only update parent-driven assigns
      socket
      |> assign(repo: assigns.repo, database: assigns.database)
      |> ok()
    else
      # First mount or database changed — full init
      messages = Databases.list_chat_messages(assigns.database.id)

      socket
      |> assign(assigns)
      |> assign(
        database_id: assigns.database.id,
        messages: messages,
        input: "",
        loading: false,
        error: nil,
        task_ref: nil
      )
      |> ok()
    end
  end

  @impl true
  def handle_event("send-message", %{"message" => message}, socket) when message != "" do
    %{database_id: database_id, repo: repo, messages: messages} = socket.assigns

    {:ok, user_msg} =
      Databases.create_chat_message(%{
        role: "user",
        content: message,
        database_id: database_id
      })

    messages = messages ++ [user_msg]
    parent = self()
    task_ref = make_ref()

    Task.start(fn ->
      result = AI.chat(repo, messages)
      send(parent, {__MODULE__, {:ai_response, task_ref, result}})
    end)

    socket
    |> assign(messages: messages, input: "", loading: true, error: nil, task_ref: task_ref)
    |> noreply()
  end

  def handle_event("send-message", _params, socket), do: noreply(socket)

  @impl true
  def handle_event("update-input", %{"message" => value}, socket) do
    socket |> assign(input: value) |> noreply()
  end

  @impl true
  def handle_event("insert-sql", %{"sql" => sql}, socket) do
    notify_parent({:insert_sql, sql})
    noreply(socket)
  end

  @impl true
  def handle_event("run-sql", %{"sql" => sql}, socket) do
    notify_parent({:run_sql, sql})
    noreply(socket)
  end

  @impl true
  def handle_event("clear-chat", _params, socket) do
    Databases.clear_chat_messages(socket.assigns.database_id)

    socket
    |> assign(messages: [], error: nil)
    |> noreply()
  end

  @impl true
  def handle_event("close-panel", _params, socket) do
    notify_parent(:close_ai_panel)
    noreply(socket)
  end

  defp handle_ai_response(socket, ref, result) do
    if socket.assigns[:task_ref] == ref do
      case result do
        {:ok, text} ->
          {:ok, assistant_msg} =
            Databases.create_chat_message(%{
              role: "assistant",
              content: text,
              database_id: socket.assigns.database_id
            })

          assign(socket,
            messages: socket.assigns.messages ++ [assistant_msg],
            loading: false
          )

        {:error, error} ->
          assign(socket, loading: false, error: error)
      end
    else
      socket
    end
  end

  defp parse_message_parts(content) do
    parts = Regex.split(~r/```sql\n?(.*?)```/s, content, include_captures: true)

    Enum.map(parts, fn part ->
      case Regex.run(~r/```sql\n?(.*?)```/s, part) do
        [_, sql] -> {:sql, String.trim(sql)}
        nil -> {:text, part}
      end
    end)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
