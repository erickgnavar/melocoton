defmodule Melocoton.AI.ModelsTest do
  use ExUnit.Case, async: true

  alias Melocoton.AI.Models

  describe "provider_options/0" do
    test "returns all providers as {label, id} tuples" do
      options = Models.provider_options()
      assert {"Anthropic", "anthropic"} in options
      assert {"OpenAI", "openai"} in options
      assert {"OpenRouter", "openrouter"} in options
      assert {"MiniMax", "minimax"} in options
    end
  end

  describe "model_options/1" do
    test "returns models for a valid provider" do
      options = Models.model_options("anthropic")
      assert {"Claude Sonnet 4.6", "claude-sonnet-4-6"} in options
      assert {"Claude Opus 4.6", "claude-opus-4-6"} in options
    end

    test "returns empty list for unknown provider" do
      assert Models.model_options("unknown") == []
    end

    test "returns empty list for nil" do
      assert Models.model_options(nil) == []
    end
  end

  describe "parse_model_string/1" do
    test "parses provider:model format" do
      assert Models.parse_model_string("anthropic:claude-sonnet-4-6") ==
               {"anthropic", "claude-sonnet-4-6"}
    end

    test "handles openrouter nested format" do
      assert Models.parse_model_string("openrouter:anthropic/claude-sonnet-4-6") ==
               {"openrouter", "anthropic/claude-sonnet-4-6"}
    end

    test "returns nils for empty string" do
      assert Models.parse_model_string("") == {nil, nil}
    end

    test "returns nils for nil" do
      assert Models.parse_model_string(nil) == {nil, nil}
    end
  end

  describe "build_model_string/2" do
    test "combines provider and model" do
      assert Models.build_model_string("anthropic", "claude-sonnet-4-6") ==
               "anthropic:claude-sonnet-4-6"
    end

    test "returns nil for nil provider" do
      assert Models.build_model_string(nil, "model") == nil
    end

    test "returns nil for nil model" do
      assert Models.build_model_string("anthropic", nil) == nil
    end

    test "returns nil for empty strings" do
      assert Models.build_model_string("", "model") == nil
      assert Models.build_model_string("provider", "") == nil
    end
  end

  describe "required_api_key/1" do
    test "maps each provider to its key setting" do
      assert Models.required_api_key("anthropic") == "anthropic_api_key"
      assert Models.required_api_key("openai") == "openai_api_key"
      assert Models.required_api_key("openrouter") == "openrouter_api_key"
      assert Models.required_api_key("minimax") == "minimax_api_key"
    end

    test "returns nil for unknown provider" do
      assert Models.required_api_key("unknown") == nil
      assert Models.required_api_key(nil) == nil
    end
  end
end
