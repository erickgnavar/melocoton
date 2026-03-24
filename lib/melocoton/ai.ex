defmodule Melocoton.AI do
  @moduledoc """
  AI service for SQL query generation using the connected database's schema as context.
  Uses ReqLLM for provider-agnostic LLM integration.
  """

  alias Melocoton.DatabaseClient

  @doc """
  Sends a chat message to the configured LLM with database schema context.

  Returns `{:ok, response_text}` or `{:error, reason}`.
  """
  def chat(conn, messages, opts \\ []) do
    model_str = opts[:model] || get_in(Application.get_env(:melocoton, :ai, []), [:model])

    if is_nil(model_str) or model_str == "" do
      {:error, "No AI model configured. Go to Settings to set a model and API key."}
    else
      do_chat(conn, messages, model_str)
    end
  end

  defp do_chat(conn, messages, model_str) do
    system_prompt = build_system_prompt(conn)

    llm_messages =
      [%{role: "system", content: system_prompt}] ++
        Enum.map(messages, fn m -> %{role: m.role, content: m.content} end)

    case parse_provider(model_str) do
      {:minimax, model_name} ->
        Melocoton.AI.MinimaxProvider.chat(llm_messages, model: model_name)

      _ ->
        case ReqLLM.generate_text(model_str, llm_messages) do
          {:ok, %{message: %{content: content}}} ->
            {:ok, extract_text(content)}

          {:error, error} ->
            {:error, "LLM error: #{inspect(error)}"}
        end
    end
  end

  defp parse_provider("minimax:" <> model), do: {:minimax, model}
  defp parse_provider(_), do: :standard

  # Content can be a plain string, a list of ContentPart structs, or other formats
  defp extract_text(content) when is_binary(content), do: content

  defp extract_text(parts) when is_list(parts) do
    Enum.map_join(parts, "", fn
      %{text: text} -> text
      %{content: text} when is_binary(text) -> text
      other -> to_string(other)
    end)
  end

  defp extract_text(other), do: to_string(other)

  @doc """
  Builds a system prompt with the full database schema for LLM context.
  """
  def build_system_prompt(conn) do
    db_type = if conn.type == :postgres, do: "PostgreSQL", else: "SQLite"
    schema_text = build_schema_text(conn)

    """
    You are a SQL assistant for a #{db_type} database.

    #{schema_text}

    Rules:
    - Generate valid #{db_type} SQL
    - When the user asks for a query, respond with the SQL inside a ```sql code block
    - You can include a brief explanation before or after the SQL if helpful
    - If the user's request is ambiguous, ask for clarification
    - Use the exact table and column names from the schema above
    - Consider foreign key relationships when joining tables
    """
  end

  defp build_schema_text(conn) do
    case DatabaseClient.get_tables(conn) do
      {:ok, tables} ->
        table_descriptions =
          Enum.map_join(tables, "\n\n", fn table ->
            cols =
              Enum.map_join(table.cols, "\n", fn col -> "    - #{col.name} (#{col.type})" end)

            "  Table: #{table.name}\n#{cols}"
          end)

        "Database schema:\n#{table_descriptions}"

      {:error, _} ->
        "Database schema: unavailable"
    end
  end
end
