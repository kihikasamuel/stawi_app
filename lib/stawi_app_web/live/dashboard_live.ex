defmodule StawiAppWeb.DashboardLive do
  use StawiAppWeb, :live_view

  alias StawiApp.Reports
  alias StawiApp.Sales
  alias StawiApp.Expenses

  @impl true
  def mount(_params, _session, socket) do
    summary = Reports.dashboard_summary()
    recent_sales = Enum.take(Sales.list_sales(), 5)
    recent_expenses = Enum.take(Expenses.list_expenses(), 5)

    {:ok,
     socket
     |> assign(:summary, summary)
     |> stream(:sales, recent_sales)
     |> stream(:expenses, recent_expenses)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <%!-- Welcome Header & Quick Action --%>
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-gradient-to-r from-base-100 to-base-200 p-5 rounded-2xl border border-base-300 shadow-xs">
          <div>
            <h1 class="text-2xl font-black tracking-tight text-base-content flex items-center gap-2">
              <span>Merchant Dashboard</span>
              <div class="badge badge-primary badge-sm font-semibold">Live Store</div>
            </h1>
            <p class="text-sm text-base-content/70 mt-0.5">
              Real-time sales tracking & double-entry accounting overview
            </p>
          </div>

          <div class="flex items-center gap-2">
            <.link
              navigate={~p"/app/pos"}
              class="btn btn-primary shadow-md font-bold flex-1 sm:flex-none"
            >
              <.icon name="hero-shopping-bag" class="w-5 h-5 mr-1" /> Start Walk-In Sale
            </.link>
          </div>
        </div>

        <%!-- KPI Metrics Grid --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
          <%!-- Card 1: Today's Sales --%>
          <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-xs">
            <div class="flex items-center justify-between text-base-content/60 mb-2">
              <span class="text-xs font-semibold uppercase tracking-wider">Today's Sales</span>
              <div class="w-8 h-8 rounded-xl bg-primary/10 text-primary flex items-center justify-center">
                <.icon name="hero-currency-dollar" class="w-5 h-5" />
              </div>
            </div>
            <div class="text-xl sm:text-2xl font-black text-base-content">
              KES {format_money(@summary.today_sales_total)}
            </div>
            <div class="text-xs text-base-content/60 mt-1 flex items-center justify-between">
              <span>{@summary.today_sales_count} sales recorded</span>
              <span class="text-success font-bold">Today</span>
            </div>
          </div>

          <%!-- Card 2: Net Profit Month --%>
          <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-xs">
            <div class="flex items-center justify-between text-base-content/60 mb-2">
              <span class="text-xs font-semibold uppercase tracking-wider">Month Net Profit</span>
              <div class="w-8 h-8 rounded-xl bg-success/10 text-success flex items-center justify-center">
                <.icon name="hero-chart-bar" class="w-5 h-5" />
              </div>
            </div>
            <div class={[
              "text-xl sm:text-2xl font-black",
              if(Decimal.gt?(@summary.month_net_profit, 0), do: "text-success", else: "text-error")
            ]}>
              KES {format_money(@summary.month_net_profit)}
            </div>
            <div class="text-xs text-base-content/60 mt-1 flex items-center justify-between">
              <span>Sales: KES {format_money(@summary.month_sales)}</span>
            </div>
          </div>

          <%!-- Card 3: Total Liquid Cash --%>
          <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-xs">
            <div class="flex items-center justify-between text-base-content/60 mb-2">
              <span class="text-xs font-semibold uppercase tracking-wider">Cash & M-Pesa</span>
              <div class="w-8 h-8 rounded-xl bg-accent/10 text-accent flex items-center justify-center">
                <.icon name="hero-building-library" class="w-5 h-5" />
              </div>
            </div>
            <div class="text-xl sm:text-2xl font-black text-base-content">
              KES {format_money(Decimal.add(@summary.cash_balance, @summary.mpesa_balance))}
            </div>
            <div class="text-xs text-base-content/60 mt-1 flex items-center justify-between">
              <span>M-Pesa: {format_money(@summary.mpesa_balance)}</span>
              <span>Cash: {format_money(@summary.cash_balance)}</span>
            </div>
          </div>

          <%!-- Card 4: Store Credit & Low Stock --%>
          <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-xs">
            <div class="flex items-center justify-between text-base-content/60 mb-2">
              <span class="text-xs font-semibold uppercase tracking-wider">Customer Debt</span>
              <div class="w-8 h-8 rounded-xl bg-warning/10 text-warning flex items-center justify-center">
                <.icon name="hero-clock" class="w-5 h-5" />
              </div>
            </div>
            <div class="text-xl sm:text-2xl font-black text-warning">
              KES {format_money(@summary.ar_balance)}
            </div>
            <div class="text-xs text-base-content/60 mt-1 flex items-center justify-between">
              <span>Low stock items:</span>
              <span class="badge badge-warning badge-sm font-bold">{@summary.low_stock_count} alert</span>
            </div>
          </div>
        </div>

        <%!-- Main Activity Grid --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- Recent Walk-in Sales --%>
          <div class="bg-base-100 border border-base-300 rounded-2xl p-4 sm:p-5 shadow-xs space-y-4">
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <h2 class="font-bold text-lg flex items-center gap-2">
                <.icon name="hero-receipt-percent" class="w-5 h-5 text-accent" /> Recent Sales
              </h2>
              <.link navigate={~p"/app/sales"} class="btn btn-ghost btn-xs text-primary">
                View All &rarr;
              </.link>
            </div>

            <div id="dashboard-recent-sales" phx-update="stream" class="space-y-3">
              <div
                id="no-recent-sales-msg"
                class="hidden only:block text-center py-6 text-base-content/50 text-sm"
              >
                No sales recorded yet.
              </div>

              <div
                :for={{id, sale} <- @streams.sales}
                id={id}
                class="flex items-center justify-between p-3 rounded-xl bg-base-200/50 hover:bg-base-200 transition-colors"
              >
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-xl bg-primary/10 text-primary font-black flex items-center justify-center text-xs">
                    POS
                  </div>
                  <div>
                    <div class="font-bold text-sm text-base-content flex items-center gap-1.5">
                      <span>{sale.sale_number}</span>
                      <span class={[
                        "badge badge-xs font-semibold uppercase",
                        if(sale.payment_method == "cash", do: "badge-success"),
                        if(sale.payment_method == "mpesa", do: "badge-primary"),
                        if(sale.payment_method == "credit", do: "badge-warning")
                      ]}>
                        {sale.payment_method}
                      </span>
                    </div>
                    <div class="text-xs text-base-content/60">
                      {if sale.customer, do: sale.customer.name, else: "Walk-in Customer"} &bull; {format_time(
                        sale.sale_date
                      )}
                    </div>
                  </div>
                </div>

                <div class="text-right">
                  <div class="font-black text-sm text-base-content">
                    KES {format_money(sale.total_amount)}
                  </div>
                  <div class="text-xs text-base-content/60">
                    {length(sale.sale_items)} items
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Recent Expenses --%>
          <div class="bg-base-100 border border-base-300 rounded-2xl p-4 sm:p-5 shadow-xs space-y-4">
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <h2 class="font-bold text-lg flex items-center gap-2">
                <.icon name="hero-banknotes" class="w-5 h-5 text-warning" /> Recent Expenses
              </h2>
              <.link navigate={~p"/app/expenses"} class="btn btn-ghost btn-xs text-primary">
                View All &rarr;
              </.link>
            </div>

            <div id="dashboard-recent-expenses" phx-update="stream" class="space-y-3">
              <div
                id="no-recent-expenses-msg"
                class="hidden only:block text-center py-6 text-base-content/50 text-sm"
              >
                No expenses logged yet.
              </div>

              <div
                :for={{id, expense} <- @streams.expenses}
                id={id}
                class="flex items-center justify-between p-3 rounded-xl bg-base-200/50 hover:bg-base-200 transition-colors"
              >
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-xl bg-warning/10 text-warning font-black flex items-center justify-center text-xs">
                    EXP
                  </div>
                  <div>
                    <div class="font-bold text-sm text-base-content">
                      {expense.description}
                    </div>
                    <div class="text-xs text-base-content/60 capitalize">
                      {expense.category} &bull; Paid via {expense.payment_method}
                    </div>
                  </div>
                </div>

                <div class="text-right">
                  <div class="font-black text-sm text-error">
                    - KES {format_money(expense.amount)}
                  </div>
                  <div class="text-xs text-base-content/60">
                    {expense.date}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_money(nil), do: "0.00"

  defp format_money(%Decimal{} = val) do
    val
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end

  defp format_money(val) when is_integer(val), do: format_money(Decimal.new(val))
  defp format_money(val) when is_float(val), do: format_money(Decimal.from_float(val))
  defp format_money(val) when is_binary(val), do: format_money(Decimal.new(val))
  defp format_money(_), do: "0.00"

  defp format_time(nil), do: ""

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%I:%M %p")
  end

  defp format_time(_), do: ""
end
