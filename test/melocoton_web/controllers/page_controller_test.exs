defmodule MelocotonWeb.PageControllerTest do
  use MelocotonWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/databases"
  end
end
