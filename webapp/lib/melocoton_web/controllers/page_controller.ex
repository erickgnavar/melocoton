defmodule MelocotonWeb.PageController do
  use MelocotonWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def export_csv(conn, %{"pid" => pid_str}) do
    csv_content =
      pid_str
      |> String.replace("#PID<", "")
      |> String.replace(">", "")
      |> IEx.Helpers.pid()
      |> :sys.get_state()
      |> Map.get(:socket)
      |> Map.get(:assigns)
      |> Map.get(:result)
      |> then(fn %{rows: rows, cols: cols} ->
        rows
        |> CSV.encode(headers: cols)
        |> Enum.to_list()
        |> to_string()
      end)

    send_download(conn, {:binary, csv_content}, filename: "result.csv")
  end
end
