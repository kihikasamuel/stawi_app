defmodule StawiAppWeb.PageControllerTest do
  use StawiAppWeb.ConnCase

  test "GET / home page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Peace of mind"
  end
end
