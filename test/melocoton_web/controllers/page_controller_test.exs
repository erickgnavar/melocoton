defmodule MelocotonWeb.PageControllerTest do
  use MelocotonWeb.ConnCase

  alias Melocoton.ExportStore

  @export_data %{
    result: %{
      cols: ["id", "name"],
      rows: [
        %{"id" => 1, "name" => "alice"},
        %{"id" => 2, "name" => "bob"}
      ],
      num_rows: 2
    },
    database_name: "my_database"
  }

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/databases"
  end

  describe "export CSV" do
    test "downloads CSV file", %{conn: conn} do
      token = ExportStore.put(@export_data)
      conn = get(conn, ~p"/export/csv/#{token}")

      assert response_content_type(conn, :csv) =~ "text/csv"
      body = response(conn, 200)
      assert body =~ "id,name"
      assert body =~ "alice"
      assert body =~ "bob"
    end

    test "token is single-use", %{conn: conn} do
      token = ExportStore.put(@export_data)

      conn1 = get(conn, ~p"/export/csv/#{token}")
      assert response(conn1, 200) =~ "alice"

      conn2 = get(conn, ~p"/export/csv/#{token}")
      assert response(conn2, 404) =~ "Export not found"
    end
  end

  describe "export Excel" do
    test "downloads XLSX file", %{conn: conn} do
      token = ExportStore.put(@export_data)
      conn = get(conn, ~p"/export/xlsx/#{token}")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "my_database_"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ ".xlsx"
    end
  end

  describe "export errors" do
    test "returns 404 for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/export/csv/invalid-token")

      assert response(conn, 404) =~ "Export not found"
    end
  end
end
