defmodule Melocoton.AI.MinimaxProvider do
  @moduledoc """
  Minimax LLM provider for ReqLLM.

  Minimax exposes an OpenAI-compatible chat completions API.
  Set MINIMAX_API_KEY to use directly, or use via OpenRouter
  with model string "openrouter:minimax/minimax-01".

  ## Direct usage

      AI_MODEL=minimax:minimax-01
      MINIMAX_API_KEY=your_key

  ## Via OpenRouter

      AI_MODEL=openrouter:minimax/minimax-01
      OPENROUTER_API_KEY=your_key
  """

  @base_url "https://api.minimax.chat/v1"

  def chat(messages, opts \\ []) do
    api_key =
      opts[:api_key] ||
        Application.get_env(:req_llm, :minimax_api_key) ||
        System.get_env("MINIMAX_API_KEY")

    model = opts[:model] || "minimax-01"

    if api_key do
      body = %{
        model: model,
        messages: messages,
        max_tokens: opts[:max_tokens] || 4096
      }

      request =
        Req.new(
          url: "#{@base_url}/chat/completions",
          json: body,
          headers: [
            {"authorization", "Bearer #{api_key}"},
            {"content-type", "application/json"}
          ]
        )

      case Req.post(request) do
        {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
          {:ok, content}

        {:ok, %{status: status, body: body}} ->
          {:error, "Minimax API error (#{status}): #{inspect(body)}"}

        {:error, error} ->
          {:error, "Minimax request failed: #{inspect(error)}"}
      end
    else
      {:error, "MINIMAX_API_KEY not configured"}
    end
  end
end
