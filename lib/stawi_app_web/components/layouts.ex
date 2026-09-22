defmodule StawiAppWeb.Layouts do
  @moduledoc """
  Mobile-first layout system for Stawi SME Accounting & Sales app using DaisyUI v5 & Tailwind CSS.
  """
  use StawiAppWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200/50 text-base-content flex flex-col font-sans pb-24 md:pb-8">
      <%!-- Top Sticky Navbar --%>
      <header class="navbar bg-base-100 border-b border-base-300 sticky top-0 z-30 px-3 sm:px-6 shadow-xs">
        <div class="flex-1 items-center gap-3">
          <.link navigate={~p"/app/home"} class="flex items-center gap-2.5 group">
            <div class="w-9 h-9 rounded-xl bg-gradient-to-tr from-primary to-accent flex items-center justify-center text-primary-content font-black text-lg shadow-md group-hover:scale-105 transition-transform">
              S
            </div>
            <div>
              <span class="font-extrabold text-lg tracking-tight bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
                STAWI
              </span>
              <span class="text-xs font-semibold text-base-content/60 block -mt-1">
                SME Accounting
              </span>
            </div>
          </.link>
        </div>
        <%= if @current_scope do %>
          <%!-- Desktop Nav Links --%>
          <div class="hidden lg:flex items-center gap-1">
            <.link navigate={~p"/app/home"} class="btn btn-ghost btn-sm rounded-lg font-medium">
              <.icon name="hero-home" class="w-4 h-4 mr-1 text-primary" /> Dashboard
            </.link>
            <.link
              navigate={~p"/app/pos"}
              class="btn btn-primary btn-sm rounded-lg font-bold shadow-xs"
            >
              <.icon name="hero-shopping-bag" class="w-4 h-4 mr-1" /> Quick POS
            </.link>
            <.link navigate={~p"/app/sales"} class="btn btn-ghost btn-sm rounded-lg font-medium">
              <.icon name="hero-receipt-percent" class="w-4 h-4 mr-1 text-accent" /> Sales Log
            </.link>
            <.link navigate={~p"/app/expenses"} class="btn btn-ghost btn-sm rounded-lg font-medium">
              <.icon name="hero-banknotes" class="w-4 h-4 mr-1 text-warning" /> Expenses
            </.link>
            <.link navigate={~p"/app/products"} class="btn btn-ghost btn-sm rounded-lg font-medium">
              <.icon name="hero-cube" class="w-4 h-4 mr-1 text-info" /> Products
            </.link>
            <.link navigate={~p"/app/customers"} class="btn btn-ghost btn-sm rounded-lg font-medium">
              <.icon name="hero-users" class="w-4 h-4 mr-1 text-secondary" /> Customers
            </.link>
            <.link navigate={~p"/app/reports"} class="btn btn-ghost btn-sm rounded-lg font-medium">
              <.icon name="hero-chart-bar" class="w-4 h-4 mr-1 text-success" /> Financial Reports
            </.link>
          </div>
        <% end %>

        <div class="flex-none items-center gap-2 flex">
          <.theme_toggle />
          <%= if @current_scope do %>
            <div class="dropdown dropdown-end">
              <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-2">
                <span class="text-xs font-semibold text-base-content/80 max-w-[120px] truncate sm:max-w-none">
                  {@current_scope.user.email}
                </span>
                <.icon name="hero-chevron-down" class="w-3.5 h-3.5" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu bg-base-100 rounded-box z-50 w-52 p-2 shadow-lg border border-base-200 mt-2"
              >
                <li>
                  <.link href={~p"/users/settings"} class="font-medium">
                    <.icon name="hero-cog-6-tooth" class="w-4 h-4 text-base-content/70" /> Settings
                  </.link>
                </li>
                <li>
                  <.link
                    href={~p"/users/log-out"}
                    method="delete"
                    class="font-medium text-error hover:bg-error/10"
                  >
                    <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" /> Log out
                  </.link>
                </li>
              </ul>
            </div>
          <% else %>
            <.link href={~p"/users/log-in"} class="btn btn-ghost btn-sm font-medium rounded-lg">
              Log in
            </.link>
            <.link
              href={~p"/users/register"}
              class="btn btn-primary btn-sm font-bold rounded-lg shadow-xs"
            >
              Register
            </.link>
          <% end %>
        </div>
      </header>

      <%!-- Main Content View --%>
      <main class="flex-1 w-full max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 py-4 sm:py-6">
        {render_slot(@inner_block)}
      </main>

      <%= if @current_scope do %>
        <%!-- Mobile Bottom Navigation Bar --%>
        <nav class="lg:hidden fixed bottom-0 left-0 right-0 z-40 bg-base-100 border-t border-base-300 px-2 py-1.5 shadow-lg flex items-center justify-around">
          <.link
            navigate={~p"/app/home"}
            class="flex flex-col items-center py-1 px-3 text-xs font-medium rounded-lg text-base-content/70 hover:text-primary transition-colors"
          >
            <.icon name="hero-home" class="w-5 h-5 mb-0.5" />
            <span>Home</span>
          </.link>

          <.link
            navigate={~p"/app/pos"}
            class="flex flex-col items-center py-1 px-3 text-xs font-bold text-primary hover:scale-105 transition-transform"
          >
            <div class="w-10 h-10 -mt-5 rounded-full bg-gradient-to-tr from-primary to-accent flex items-center justify-center text-primary-content shadow-lg border-2 border-base-100">
              <.icon name="hero-shopping-bag" class="w-5 h-5" />
            </div>
            <span class="mt-1">POS</span>
          </.link>

          <.link
            navigate={~p"/app/sales"}
            class="flex flex-col items-center py-1 px-3 text-xs font-medium rounded-lg text-base-content/70 hover:text-accent transition-colors"
          >
            <.icon name="hero-receipt-percent" class="w-5 h-5 mb-0.5" />
            <span>Sales</span>
          </.link>

          <.link
            navigate={~p"/app/expenses"}
            class="flex flex-col items-center py-1 px-3 text-xs font-medium rounded-lg text-base-content/70 hover:text-warning transition-colors"
          >
            <.icon name="hero-banknotes" class="w-5 h-5 mb-0.5" />
            <span>Expenses</span>
          </.link>

          <.link
            navigate={~p"/app/reports"}
            class="flex flex-col items-center py-1 px-3 text-xs font-medium rounded-lg text-base-content/70 hover:text-success transition-colors"
          >
            <.icon name="hero-chart-bar" class="w-5 h-5 mb-0.5" />
            <span>Reports</span>
          </.link>
        </nav>
      <% end %>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  def flash_group(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-group" end)

    ~H"""
    <div id={@id} aria-live="polite" class="fixed bottom-20 right-4 z-50 max-w-sm space-y-2">
      <.flash kind={:info} id="flash-info" flash={@flash} />
      <.flash kind={:error} id="flash-error" flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("Connection lost")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect...")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border border-base-300 bg-base-200 rounded-full p-0.5">
      <button
        class="p-1.5 cursor-pointer rounded-full hover:bg-base-300 transition-colors"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light Mode"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="p-1.5 cursor-pointer rounded-full hover:bg-base-300 transition-colors"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Dark Mode"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
