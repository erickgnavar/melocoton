defmodule MelocotonWeb.PageController do
  use MelocotonWeb, :controller

  alias Elixlsx.{Sheet, Workbook}

  def home(conn, _params) do
    redirect(conn, to: ~p"/databases")
  end

  def export(conn, %{"pid" => pid_str, "format" => "csv"}) do
    %{rows: rows, cols: cols} = get_result(pid_str)

    csv_content =
      rows
      |> CSV.encode(headers: cols)
      |> Enum.to_list()
      |> to_string()

    send_download(conn, {:binary, csv_content}, filename: "result.csv")
  end

  def export(conn, %{"pid" => pid_str, "format" => "xlsx"}) do
    %{rows: rows, cols: cols} = get_result(pid_str)

    data_rows =
      Enum.map(rows, fn row ->
        Enum.map(cols, fn col -> format_cell(Map.get(row, col)) end)
      end)

    sheet = %Sheet{name: "Results", rows: [cols | data_rows]}

    {:ok, {_filename, binary}} =
      Workbook.append_sheet(%Workbook{}, sheet) |> Elixlsx.write_to_memory("result.xlsx")

    send_download(conn, {:binary, binary}, filename: "result.xlsx")
  end

  defp get_result(pid_str) do
    pid_str
    |> String.replace("#PID<", "")
    |> String.replace(">", "")
    |> IEx.Helpers.pid()
    |> :sys.get_state()
    |> Map.get(:socket)
    |> Map.get(:assigns)
    |> Map.get(:result)
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
