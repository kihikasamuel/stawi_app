defmodule StawiAppWeb.Router do
  use StawiAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StawiAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", StawiAppWeb do
    pipe_through :browser

    live "/", DashboardLive
    live "/pos", PosLive
    live "/sales", SalesLive
    live "/products", ProductsLive
    live "/expenses", ExpensesLive
    live "/customers", CustomersLive
    live "/reports", ReportsLive
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:stawi_app, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: StawiAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
