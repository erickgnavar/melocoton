defmodule Melocoton.Shortcuts do
  @moduledoc """
  Central registry of all keyboard shortcuts in the application.
  Single source of truth — UI rendering and event handlers reference this.
  Each shortcut is a {keys, context, description} tuple.
  """

  @context_labels %{
    global: "Global",
    sql_editor: "SQL Editor",
    databases: "Connections",
    table_explorer: "Table Explorer"
  }

  @shortcut_data [
    # Global
    {["⌘", "K"], :global, "Command palette"},
    {["⌘", ","], :global, "Settings"},
    {["⌘", "B"], :global, "Toggle AI panel"},
    {["?"], :global, "Keyboard shortcuts"},

    # SQL Editor
    {["⌘", "Enter"], :sql_editor, "Run query (selection or all)"},
    {["⌘", "S"], :sql_editor, "Save query to file"},
    {["⌘", "⇧", "F"], :sql_editor, "Format SQL"},
    {["Tab"], :sql_editor, "Accept autocomplete suggestion"},
    {["Ctrl", "N"], :sql_editor, "Next autocomplete suggestion"},
    {["Ctrl", "P"], :sql_editor, "Previous autocomplete suggestion"},

    # Vim mode
    {["g", "t"], :sql_editor, "Next session tab (Vim)"},
    {["g", "T"], :sql_editor, "Previous session tab (Vim)"},
    {[":format"], :sql_editor, "Format SQL (Vim)"},
    {[":tabnext"], :sql_editor, "Next session tab (Vim)"},
    {[":tabprev"], :sql_editor, "Previous session tab (Vim)"},

    # Databases page
    {["/"], :databases, "Focus search"},

    # Table explorer
    {["Escape"], :table_explorer, "Cancel cell edit"},
    {["⌘", "Enter"], :table_explorer, "Set cell to NULL"}
  ]

  @grouped_data @shortcut_data
                |> Enum.map(fn {_, ctx, _} -> ctx end)
                |> Enum.uniq()
                |> Enum.map(fn ctx ->
                  %{
                    label: @context_labels[ctx],
                    shortcuts: Enum.filter(@shortcut_data, fn {_, c, _} -> c == ctx end)
                  }
                end)

  @doc "Returns all shortcuts grouped by context, precomputed at compile time."
  def grouped, do: @grouped_data
end
