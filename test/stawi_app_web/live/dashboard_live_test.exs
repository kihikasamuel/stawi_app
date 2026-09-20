defmodule StawiAppWeb.DashboardLiveTest do
  use StawiAppWeb.ConnCase
  import Phoenix.LiveViewTest

  test "renders dashboard overview and metrics", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Merchant Dashboard"
    assert html =~ "Today&#39;s Sales"
    assert html =~ "Start Walk-In Sale"
  end
end
