defmodule Melocoton.AI.MinimaxProvider do
  @moduledoc """
  MiniMax LLM provider using their OpenAI-compatible chat completions API.

  API base: https://api.minimax.io/v1
  Available models: MiniMax-M2.7, MiniMax-M2.7-highspeed, MiniMax-M2.5,
  MiniMax-M2.5-highspeed, MiniMax-M2.1, MiniMax-M2.

  ## Usage

      AI_MODEL=minimax:MiniMax-M2.7
      MINIMAX_API_KEY=sk-cp-...
  """

  @base_url "https://api.minimax.io/v1"

  def chat(messages, opts \\ []) do
    api_key =
      opts[:api_key] ||
        Application.get_env(:req_llm, :minimax_api_key) ||
        System.get_env("MINIMAX_API_KEY")

    model = opts[:model] || "MiniMax-M2.7"

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
          ],
          connect_options: [timeout: :timer.seconds(60)],
          receive_timeout: :timer.seconds(300)
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
