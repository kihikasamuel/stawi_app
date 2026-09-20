defmodule StawiAppWeb.PageController do
  use StawiAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
