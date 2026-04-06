defmodule MelocotonWeb.SqlLive.DatabaseDiagramComponent do
  use MelocotonWeb, :live_component

  alias Melocoton.DatabaseClient

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_async(:diagram_data, fn ->
      load_diagram(assigns.conn, assigns.tables)
    end)
    |> ok()
  end

  defp load_diagram(conn, tables_async) do
    tables =
      case tables_async do
        %{ok?: true, result: t} when is_list(t) -> t
        _ -> []
      end

    relations =
      case DatabaseClient.get_all_relations(conn) do
        {:ok, rels} -> rels
        _ -> []
      end

    mermaid = build_mermaid(tables, relations)
    {:ok, %{diagram_data: mermaid}}
  end

  defp build_mermaid([], _relations), do: ""

  defp build_mermaid(tables, relations) do
    table_defs =
      Enum.map_join(tables, "\n", fn table ->
        cols =
          Enum.map_join(table.cols || [], "\n", fn col ->
            type = sanitize(col.type)
            name = sanitize(col.name)
            "    #{type} #{name}"
          end)

        "  #{sanitize(table.name)} {\n#{cols}\n  }"
      end)

    relation_defs =
      Enum.map_join(relations, "\n", fn rel ->
        from = sanitize(rel.from_table)
        to = sanitize(rel.to_table)
        label = sanitize("#{rel.from_column} -> #{rel.to_column}")
        ~s(  #{to} ||--o{ #{from} : "#{label}")
      end)

    "erDiagram\n#{table_defs}\n#{relation_defs}"
  end

  defp sanitize(str) when is_binary(str) do
    str
    |> String.replace(~r/[^a-zA-Z0-9_\->\s]/, "_")
    |> String.replace(" ", "_")
  end

  defp sanitize(other), do: to_string(other) |> sanitize()
end
