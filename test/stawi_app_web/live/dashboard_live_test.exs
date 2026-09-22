defmodule StawiAppWeb.DashboardLiveTest do
  use StawiAppWeb.ConnCase
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "renders dashboard overview and metrics", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/app/home")

    assert html =~ "Merchant Dashboard"
    assert html =~ "Today&#39;s Sales"
    assert html =~ "Start Walk-In Sale"
  end
end
