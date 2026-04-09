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

  describe "export SQL" do
    test "downloads SQL file with query content", %{conn: conn} do
      token = ExportStore.put(%{query: "SELECT * FROM users;", database_name: "my_database"})
      conn = get(conn, ~p"/export/sql/#{token}")

      assert response(conn, 200) == "SELECT * FROM users;"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "my_database_"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ ".sql"
    end
  end

  describe "export CSV with complex types" do
    test "formats nil as empty string", %{conn: conn} do
      token = put_export([%{"val" => nil}], ["val"])
      body = csv_body(conn, token)
      assert body =~ "\r\n\r\n"
    end

    test "formats DateTime", %{conn: conn} do
      dt = ~U[2024-06-15 10:30:00Z]
      token = put_export([%{"ts" => dt}], ["ts"])
      body = csv_body(conn, token)
      assert body =~ "2024-06-15 10:30:00Z"
    end

    test "formats NaiveDateTime", %{conn: conn} do
      ndt = ~N[2024-06-15 10:30:00]
      token = put_export([%{"ts" => ndt}], ["ts"])
      body = csv_body(conn, token)
      assert body =~ "2024-06-15 10:30:00"
    end

    test "formats Date", %{conn: conn} do
      token = put_export([%{"d" => ~D[2024-06-15]}], ["d"])
      body = csv_body(conn, token)
      assert body =~ "2024-06-15"
    end

    test "formats Time", %{conn: conn} do
      token = put_export([%{"t" => ~T[10:30:00]}], ["t"])
      body = csv_body(conn, token)
      assert body =~ "10:30:00"
    end

    test "formats Decimal", %{conn: conn} do
      token = put_export([%{"n" => Decimal.new("3.14")}], ["n"])
      body = csv_body(conn, token)
      assert body =~ "3.14"
    end

    test "formats lists as JSON", %{conn: conn} do
      token = put_export([%{"tags" => [1, 2, 3]}], ["tags"])
      body = csv_body(conn, token)
      assert body =~ "[1,2,3]"
    end

    test "formats maps as JSON", %{conn: conn} do
      token = put_export([%{"data" => %{"key" => "value"}}], ["data"])
      body = csv_body(conn, token)
      assert body =~ ~s("key")
      assert body =~ ~s("value")
    end

    test "formats booleans", %{conn: conn} do
      token = put_export([%{"flag" => true}, %{"flag" => false}], ["flag"])
      body = csv_body(conn, token)
      assert body =~ "true"
      assert body =~ "false"
    end

    test "passes through strings and numbers", %{conn: conn} do
      token = put_export([%{"name" => "alice", "age" => 30}], ["name", "age"])
      body = csv_body(conn, token)
      assert body =~ "alice"
      assert body =~ "30"
    end
  end

  describe "export Excel with complex types" do
    test "formats nil as empty string", %{conn: conn} do
      token = put_export([%{"val" => nil}], ["val"])
      conn = get(conn, ~p"/export/xlsx/#{token}")
      assert response(conn, 200)
    end

    test "formats DateTime", %{conn: conn} do
      token = put_export([%{"ts" => ~U[2024-06-15 10:30:00Z]}], ["ts"])
      conn = get(conn, ~p"/export/xlsx/#{token}")
      assert response(conn, 200)
    end

    test "formats Date and Time", %{conn: conn} do
      token = put_export([%{"d" => ~D[2024-06-15], "t" => ~T[10:30:00]}], ["d", "t"])
      conn = get(conn, ~p"/export/xlsx/#{token}")
      assert response(conn, 200)
    end

    test "formats Decimal", %{conn: conn} do
      token = put_export([%{"n" => Decimal.new("3.14")}], ["n"])
      conn = get(conn, ~p"/export/xlsx/#{token}")
      assert response(conn, 200)
    end

    test "formats lists and maps as JSON strings", %{conn: conn} do
      token =
        put_export(
          [%{"tags" => [1, 2, 3], "data" => %{"key" => "value"}}],
          ["tags", "data"]
        )

      conn = get(conn, ~p"/export/xlsx/#{token}")
      assert response(conn, 200)
    end

    test "formats booleans", %{conn: conn} do
      token = put_export([%{"flag" => true}], ["flag"])
      conn = get(conn, ~p"/export/xlsx/#{token}")
      assert response(conn, 200)
    end
  end

  describe "export errors" do
    test "returns 404 for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/export/csv/invalid-token")

      assert response(conn, 404) =~ "Export not found"
    end
  end

  defp put_export(rows, cols) do
    ExportStore.put(%{
      result: %{cols: cols, rows: rows, num_rows: length(rows)},
      database_name: "test_db"
    })
  end

  defp csv_body(conn, token) do
    conn = get(conn, ~p"/export/csv/#{token}")
    response(conn, 200)
  end
end
