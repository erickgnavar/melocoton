defmodule Melocoton.AI.Ollama do
  @moduledoc """
  Ollama integration for local LLM inference.

  Fetches available models from a running Ollama instance and builds
  ReqLLM-compatible model specs using the OpenAI-compatible endpoint.
  """

  @base_url "http://localhost:11434"

  @doc """
  Lists models installed in the local Ollama instance.

  Returns a list of `{label, id}` tuples for use in the settings UI.
  Returns `[]` if Ollama is not running or unreachable.
  """
  def list_models do
    case Req.get("#{@base_url}/api/tags", receive_timeout: 3_000) do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        models
        |> Enum.map(fn m ->
          name = m["name"]
          {name, name}
        end)
        |> Enum.sort_by(&elem(&1, 0))

      _ ->
        []
    end
  end

  @doc """
  Builds a ReqLLM model struct for the given Ollama model name.
  """
  def model(name) do
    ReqLLM.model!(%{id: name, provider: :openai, base_url: "#{@base_url}/v1"})
  end
end
