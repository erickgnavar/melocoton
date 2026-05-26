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
    {"ollama", "Ollama", :dynamic},
    {"opencode", "OpenCode",
     [
       {"zen/deepseek-v4-flash-free", "Free: DeepSeek V4 Flash Free"},
       {"zen/big-pickle", "Free: Big Pickle"},
       {"zen/nemotron-3-super-free", "Free: Nemotron 3 Super Free"},
       {"go/deepseek-v4-flash", "Go: DeepSeek V4 Flash"},
       {"go/deepseek-v4-pro", "Go: DeepSeek V4 Pro"},
       {"go/qwen3.6-plus", "Go: Qwen3.6 Plus"},
       {"go/qwen3.5-plus", "Go: Qwen3.5 Plus"},
       {"go/glm-5.1", "Go: GLM-5.1"},
       {"go/glm-5", "Go: GLM-5"},
       {"go/kimi-k2.6", "Go: Kimi K2.6"},
       {"go/kimi-k2.5", "Go: Kimi K2.5"},
       {"go/mimo-v2.5-pro", "Go: MiMo-V2.5-Pro"},
       {"go/mimo-v2.5", "Go: MiMo-V2.5"},
       {"go/minimax-m2.7", "Go: MiniMax M2.7"},
       {"go/minimax-m2.5", "Go: MiniMax M2.5"},
       {"zen/gpt-5.5", "Zen: GPT 5.5"},
       {"zen/gpt-5.2-codex", "Zen: GPT 5.2 Codex"},
       {"zen/gpt-5.1-codex", "Zen: GPT 5.1 Codex"},
       {"zen/claude-sonnet-4-6", "Zen: Claude Sonnet 4.6"},
       {"zen/claude-opus-4-5", "Zen: Claude Opus 4.5"},
       {"zen/claude-haiku-4-5", "Zen: Claude Haiku 4.5"},
       {"zen/gemini-3.5-flash", "Zen: Gemini 3.5 Flash"}
     ]}
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
  def required_api_key("opencode"), do: "opencode_api_key"
  def required_api_key(_), do: nil

  def build_model_string(nil, _), do: nil
  def build_model_string(_, nil), do: nil
  def build_model_string("", _), do: nil
  def build_model_string(_, ""), do: nil
  def build_model_string(provider, model), do: "#{provider}:#{model}"
end
