defmodule Melocoton.Settings do
  @moduledoc """
  Context for managing application settings stored in the local SQLite database.
  Used for API keys and other configuration that persists across sessions.
  """

  import Ecto.Query
  alias Melocoton.Repo
  alias Melocoton.Settings.Setting

  @api_key_settings [
    "anthropic_api_key",
    "openai_api_key",
    "openrouter_api_key",
    "minimax_api_key",
    "ai_model"
  ]

  def get(key) do
    case Repo.get_by(Setting, key: key) do
      nil -> nil
      setting -> setting.value
    end
  end

  def set(key, value) do
    case Repo.get_by(Setting, key: key) do
      nil ->
        %Setting{}
        |> Setting.changeset(%{key: key, value: value})
        |> Repo.insert()

      setting ->
        setting
        |> Setting.changeset(%{value: value})
        |> Repo.update()
    end
  end

  def delete(key) do
    case Repo.get_by(Setting, key: key) do
      nil -> :ok
      setting -> Repo.delete(setting)
    end
  end

  @onboarding_key "onboarding_completed"

  def onboarding_completed? do
    get(@onboarding_key) != nil
  end

  def complete_onboarding do
    set(@onboarding_key, "true")
  end

  def reset_onboarding do
    delete(@onboarding_key)
  end

  @doc """
  Returns all API key settings as a map with empty string defaults.
  """
  def get_api_key_settings do
    settings =
      Setting
      |> where([s], s.key in ^@api_key_settings)
      |> Repo.all()
      |> Map.new(fn s -> {s.key, s.value} end)

    Map.new(@api_key_settings, fn key ->
      {key, Map.get(settings, key, "")}
    end)
  end

  @doc """
  Saves multiple API key settings at once. Blank values delete the setting.
  """
  def save_api_key_settings(params) do
    Enum.each(@api_key_settings, fn key ->
      case Map.get(params, key, "") do
        "" -> delete(key)
        value -> set(key, value)
      end
    end)

    apply_api_keys_to_runtime()
    :ok
  end

  @doc """
  Loads saved API keys into the application environment so ReqLLM can use them.
  Called on application startup and after saving settings.
  """
  def apply_api_keys_to_runtime do
    if key = get("anthropic_api_key"), do: Application.put_env(:req_llm, :anthropic_api_key, key)
    if key = get("openai_api_key"), do: Application.put_env(:req_llm, :openai_api_key, key)

    if key = get("openrouter_api_key"),
      do: Application.put_env(:req_llm, :openrouter_api_key, key)

    if key = get("minimax_api_key"), do: Application.put_env(:req_llm, :minimax_api_key, key)
    if model = get("ai_model"), do: Application.put_env(:melocoton, :ai, model: model)
  end
end
