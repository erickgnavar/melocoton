defmodule Melocoton.AI.Models do
  @providers [
    {"anthropic", "Anthropic",
     [
       {"claude-sonnet-4-6", "Claude Sonnet 4.6"},
       {"claude-opus-4-6", "Claude Opus 4.6"},
       {"claude-haiku-4-5", "Claude Haiku 4.5"}
     ]},
    {"openai", "OpenAI",
     [
       {"gpt-4o", "GPT-4o"},
       {"gpt-4o-mini", "GPT-4o Mini"},
       {"gpt-4.1", "GPT-4.1"},
       {"gpt-4.1-mini", "GPT-4.1 Mini"},
       {"gpt-4.1-nano", "GPT-4.1 Nano"}
     ]},
    {"openrouter", "OpenRouter",
     [
       {"anthropic/claude-sonnet-4-6", "Claude Sonnet 4.6"},
       {"anthropic/claude-haiku-4-5", "Claude Haiku 4.5"},
       {"openai/gpt-4o", "GPT-4o"},
       {"google/gemini-2.5-pro", "Gemini 2.5 Pro"},
       {"minimax/MiniMax-M2.7", "MiniMax M2.7"}
     ]},
    {"minimax", "MiniMax",
     [
       {"MiniMax-M2.7", "MiniMax M2.7"},
       {"MiniMax-M2.7-highspeed", "MiniMax M2.7 Highspeed"},
       {"MiniMax-M2.5", "MiniMax M2.5"},
       {"MiniMax-M2.5-highspeed", "MiniMax M2.5 Highspeed"},
       {"MiniMax-M2.1", "MiniMax M2.1"},
       {"MiniMax-M2", "MiniMax M2"}
     ]},
    {"ollama", "Ollama", :dynamic}
  ]

  def providers, do: @providers

  def provider_options do
    Enum.map(@providers, fn {id, label, _} -> {label, id} end)
  end

  def model_options("ollama"), do: Melocoton.AI.Ollama.list_models()

  def model_options(provider_id) do
    case Enum.find(@providers, fn {id, _, _} -> id == provider_id end) do
      {_, _, models} when is_list(models) -> Enum.map(models, fn {id, label} -> {label, id} end)
      _ -> []
    end
  end

  def parse_model_string(nil), do: {nil, nil}
  def parse_model_string(""), do: {nil, nil}

  def parse_model_string(model_string) do
    case String.split(model_string, ":", parts: 2) do
      [provider, model] -> {provider, model}
      _ -> {nil, nil}
    end
  end

  def required_api_key("anthropic"), do: "anthropic_api_key"
  def required_api_key("openai"), do: "openai_api_key"
  def required_api_key("openrouter"), do: "openrouter_api_key"
  def required_api_key("minimax"), do: "minimax_api_key"
  def required_api_key("ollama"), do: nil
  def required_api_key(_), do: nil

  def build_model_string(nil, _), do: nil
  def build_model_string(_, nil), do: nil
  def build_model_string("", _), do: nil
  def build_model_string(_, ""), do: nil
  def build_model_string(provider, model), do: "#{provider}:#{model}"
end
