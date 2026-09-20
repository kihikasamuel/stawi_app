defmodule StawiAppWeb.PageControllerTest do
  use StawiAppWeb.ConnCase

  test "GET / dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Merchant Dashboard"
  end
end
