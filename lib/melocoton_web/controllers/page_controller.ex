defmodule MelocotonWeb.PageController do
  use MelocotonWeb, :controller

  alias Elixlsx.{Sheet, Workbook}

  def home(conn, _params) do
    redirect(conn, to: ~p"/databases")
  end

  def export(conn, %{"token" => token, "format" => format}) when format in ["csv", "xlsx"] do
    case Melocoton.ExportStore.pop(token) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Export not found")

      %{result: result, database_name: database_name} ->
        do_export(conn, format, result, database_name)
    end
  end

  defp export_filename(database_name, extension) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d_%H:%M:%S")
    slug = database_name |> String.replace(~r/[^\w-]+/, "_") |> String.trim_trailing("_")
    "#{slug}_#{timestamp}.#{extension}"
  end

  defp do_export(conn, "csv", %{rows: rows, cols: cols}, database_name) do
    csv_content =
      rows
      |> CSV.encode(headers: cols)
      |> Enum.to_list()
      |> to_string()

    send_download(conn, {:binary, csv_content}, filename: export_filename(database_name, "csv"))
  end

  defp do_export(conn, "xlsx", %{rows: rows, cols: cols}, database_name) do
    data_rows =
      Enum.map(rows, fn row ->
        Enum.map(cols, fn col -> format_cell(Map.get(row, col)) end)
      end)

    filename = export_filename(database_name, "xlsx")
    sheet = %Sheet{name: "Results", rows: [cols | data_rows]}

    {:ok, {_filename, binary}} =
      Workbook.append_sheet(%Workbook{}, sheet) |> Elixlsx.write_to_memory(filename)

    send_download(conn, {:binary, binary}, filename: filename)
  end

  defp format_cell(nil), do: ""
  defp format_cell(%DateTime{} = dt), do: DateTime.to_string(dt)
  defp format_cell(%NaiveDateTime{} = dt), do: NaiveDateTime.to_string(dt)
  defp format_cell(%Date{} = d), do: Date.to_string(d)
  defp format_cell(value) when is_binary(value), do: value
  defp format_cell(value) when is_number(value), do: value
  defp format_cell(value) when is_boolean(value), do: value
  defp format_cell(value), do: inspect(value)
end
