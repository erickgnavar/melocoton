defmodule Melocoton.Shortcuts do
  @moduledoc """
  Central registry of all keyboard shortcuts in the application.
  Single source of truth — UI rendering and event handlers reference this.
  """

  defstruct [:key, :modifiers, :context, :action, :description]

  @type t :: %__MODULE__{
          key: String.t(),
          modifiers: list(:cmd | :shift | :ctrl | :alt),
          context: :global | :sql_editor | :databases | :table_explorer,
          action: String.t(),
          description: String.t()
        }

  # Defined as keyword lists, converted to structs at compile time via function
  @shortcut_data [
    # Global
    {["⌘", "K"], :global, "Command palette"},
    {["⌘", ","], :global, "Settings"},
    {["⌘", "B"], :global, "Toggle AI panel"},
    {["?"], :global, "Keyboard shortcuts"},

    # SQL Editor
    {["⌘", "Enter"], :sql_editor, "Run query (selection or all)"},
    {["⌘", "S"], :sql_editor, "Save query to file"},
    {["g", "t"], :sql_editor, "Next session tab"},
    {["g", "T"], :sql_editor, "Previous session tab"},
    {[":format"], :sql_editor, "Format SQL"},
    {[":tabnext"], :sql_editor, "Next session tab (ex)"},
    {[":tabprev"], :sql_editor, "Previous session tab (ex)"},
    {["Tab"], :sql_editor, "Accept autocomplete suggestion"},
    {["Ctrl", "N"], :sql_editor, "Next autocomplete suggestion"},
    {["Ctrl", "P"], :sql_editor, "Previous autocomplete suggestion"},

    # Databases page
    {["/"], :databases, "Focus search"},

    # Table explorer
    {["Escape"], :table_explorer, "Cancel cell edit"},
    {["⌘", "Enter"], :table_explorer, "Set cell to NULL"}
  ]

  @doc "Returns all shortcuts as a list of {keys, context, description} tuples."
  def all, do: @shortcut_data

  @doc "Returns shortcuts for a given context."
  def for_context(context) do
    Enum.filter(@shortcut_data, fn {_keys, ctx, _desc} -> ctx == context end)
  end

  @doc "Returns all unique contexts in order."
  def contexts do
    @shortcut_data |> Enum.map(fn {_, ctx, _} -> ctx end) |> Enum.uniq()
  end

  @doc "Human-readable context label."
  def context_label(:global), do: "Global"
  def context_label(:sql_editor), do: "SQL Editor"
  def context_label(:databases), do: "Connections"
  def context_label(:table_explorer), do: "Table Explorer"
end
