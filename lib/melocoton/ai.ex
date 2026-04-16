defmodule Melocoton.AI do
  @moduledoc """
  AI service for SQL query generation using the connected database's schema as context.
  Uses ReqLLM for provider-agnostic LLM integration.
  """

  @doc """
  Sends a chat message to the configured LLM with database schema context.

  `schema` is a map with `:type` (atom) and `:tables` (list).

  Returns `{:ok, response_text}` or `{:error, reason}`.
  """
  def chat(schema, messages, opts \\ []) do
    model_str = opts[:model] || get_in(Application.get_env(:melocoton, :ai, []), [:model])

    if is_nil(model_str) or model_str == "" do
      {:error, "No AI model configured. Go to Settings to set a model and API key."}
    else
      do_chat(schema, messages, model_str)
    end
  end

  defp do_chat(schema, messages, model_str) do
    system_prompt = build_system_prompt(schema)

    llm_messages =
      [%{role: "system", content: system_prompt}] ++
        Enum.map(messages, fn m -> %{role: m.role, content: m.content} end)

    case parse_provider(model_str) do
      {:minimax, model_name} ->
        Melocoton.AI.MinimaxProvider.chat(llm_messages, model: model_name)

      {:ollama, model_name} ->
        model = Melocoton.AI.Ollama.model(model_name)

        case ReqLLM.generate_text(model, llm_messages,
               api_key: "ollama",
               receive_timeout: 300_000
             ) do
          {:ok, %{message: %{content: content}}} ->
            {:ok, extract_text(content)}

          {:error, error} ->
            {:error, "LLM error: #{inspect(error)}"}
        end

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
  defp parse_provider("ollama:" <> model), do: {:ollama, model}
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

  `schema` is a map with `:type` and `:tables`.
  """
  def build_system_prompt(schema) do
    db_type =
      case schema.type do
        :postgres -> "PostgreSQL"
        :mysql -> "MySQL"
        :sqlite -> "SQLite"
      end

    schema_text = build_schema_text(schema.tables)

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

  defp build_schema_text(tables) do
    table_descriptions =
      Enum.map_join(tables, "\n\n", fn table ->
        cols =
          Enum.map_join(table.cols, "\n", fn col -> "    - #{col.name} (#{col.type})" end)

        "  Table: #{table.name}\n#{cols}"
      end)

    "Database schema:\n#{table_descriptions}"
  end
end
