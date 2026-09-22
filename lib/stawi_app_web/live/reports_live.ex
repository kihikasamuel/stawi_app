defmodule StawiAppWeb.ReportsLive do
  use StawiAppWeb, :live_view

  alias StawiApp.Reports
  alias StawiApp.Accounting

  @impl true
  def mount(_params, _session, socket) do
    income_statement = Reports.income_statement()
    balance_sheet = Reports.balance_sheet()
    accounts = Accounting.list_accounts()

    {:ok,
     socket
     |> assign(:active_tab, "income_statement")
     |> assign(:income_statement, income_statement)
     |> assign(:balance_sheet, balance_sheet)
     |> assign(:accounts, accounts)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-base-100 p-5 rounded-2xl border border-base-300 shadow-xs">
          <div>
            <h1 class="text-2xl font-black tracking-tight text-base-content flex items-center gap-2">
              <.icon name="hero-chart-bar" class="w-6 h-6 text-success" />
              Financial Reports & General Ledger
            </h1>
            <p class="text-sm text-base-content/70 mt-0.5">
              Standard double-entry accounting statements for decision making, audits, and tax support
            </p>
          </div>

          <div class="badge badge-success badge-lg font-bold">
            Balanced Ledger
          </div>
        </div>

        <%!-- Tab Bar --%>
        <div class="flex items-center gap-2 border-b border-base-300 pb-2">
          <button
            phx-click="switch_tab"
            phx-value-tab="income_statement"
            class={[
              "btn btn-sm rounded-xl font-bold transition-all",
              if(@active_tab == "income_statement", do: "btn-primary shadow-xs", else: "btn-ghost")
            ]}
          >
            <.icon name="hero-document-chart-bar" class="w-4 h-4 mr-1" /> Profit & Loss Statement
          </button>

          <button
            phx-click="switch_tab"
            phx-value-tab="balance_sheet"
            class={[
              "btn btn-sm rounded-xl font-bold transition-all",
              if(@active_tab == "balance_sheet", do: "btn-primary shadow-xs", else: "btn-ghost")
            ]}
          >
            <.icon name="hero-scale" class="w-4 h-4 mr-1" /> Balance Sheet
          </button>

          <button
            phx-click="switch_tab"
            phx-value-tab="chart_of_accounts"
            class={[
              "btn btn-sm rounded-xl font-bold transition-all",
              if(@active_tab == "chart_of_accounts", do: "btn-primary shadow-xs", else: "btn-ghost")
            ]}
          >
            <.icon name="hero-list-bullet" class="w-4 h-4 mr-1" /> Chart of Accounts
          </button>
        </div>

        <%!-- TAB 1: Income Statement (Profit & Loss) --%>
        <%= if @active_tab == "income_statement" do %>
          <div class="bg-base-100 border border-base-300 rounded-2xl p-6 shadow-xs max-w-3xl space-y-6">
            <div class="text-center border-b border-base-200 pb-4">
              <h2 class="font-black text-xl text-base-content">INCOME STATEMENT (PROFIT & LOSS)</h2>
              <p class="text-xs text-base-content/60">For Current Trading Period</p>
            </div>

            <%!-- Sales Revenue --%>
            <div class="space-y-2">
              <h3 class="font-extrabold text-xs uppercase tracking-wider text-primary border-b border-base-200 pb-1">
                REVENUES
              </h3>
              <%= for rev <- @income_statement.revenues do %>
                <div class="flex justify-between text-sm py-1">
                  <span>{rev.code} - {rev.name}</span>
                  <span class="font-medium">KES {format_money(rev.amount)}</span>
                </div>
              <% end %>
              <div class="flex justify-between font-bold text-sm border-t border-base-200 pt-2 text-base-content">
                <span>TOTAL REVENUE</span>
                <span class="text-primary">KES {format_money(@income_statement.total_revenue)}</span>
              </div>
            </div>

            <%!-- Cost of Goods Sold --%>
            <div class="space-y-2">
              <h3 class="font-extrabold text-xs uppercase tracking-wider text-base-content/70 border-b border-base-200 pb-1">
                COST OF GOODS SOLD (COGS)
              </h3>
              <div class="flex justify-between text-sm py-1">
                <span>5010 - Cost of Goods Sold</span>
                <span class="font-medium">- KES {format_money(@income_statement.cogs)}</span>
              </div>
              <div class="flex justify-between font-black text-base border-t border-base-200 pt-2 text-base-content">
                <span>GROSS PROFIT</span>
                <span class="text-success">KES {format_money(@income_statement.gross_profit)}</span>
              </div>
            </div>

            <%!-- Operating Expenses --%>
            <div class="space-y-2">
              <h3 class="font-extrabold text-xs uppercase tracking-wider text-warning border-b border-base-200 pb-1">
                OPERATING EXPENSES
              </h3>
              <%= for exp <- @income_statement.expenses do %>
                <div class="flex justify-between text-sm py-1">
                  <span>{exp.code} - {exp.name}</span>
                  <span class="font-medium">- KES {format_money(exp.amount)}</span>
                </div>
              <% end %>
              <div class="flex justify-between font-bold text-sm border-t border-base-200 pt-2 text-warning">
                <span>TOTAL OPERATING EXPENSES</span>
                <span>- KES {format_money(@income_statement.total_expenses)}</span>
              </div>
            </div>

            <%!-- Net Income --%>
            <div class="bg-base-200/80 p-4 rounded-xl flex items-center justify-between font-black text-lg border border-base-300">
              <span>NET PROFIT / (LOSS)</span>
              <span class={[
                if(Decimal.gt?(@income_statement.net_income, 0),
                  do: "text-success",
                  else: "text-error"
                )
              ]}>
                KES {format_money(@income_statement.net_income)}
              </span>
            </div>
          </div>
        <% end %>

        <%!-- TAB 2: Balance Sheet --%>
        <%= if @active_tab == "balance_sheet" do %>
          <div class="bg-base-100 border border-base-300 rounded-2xl p-6 shadow-xs max-w-3xl space-y-6">
            <div class="text-center border-b border-base-200 pb-4">
              <h2 class="font-black text-xl text-base-content">
                STATEMENT OF FINANCIAL POSITION (BALANCE SHEET)
              </h2>
              <p class="text-xs text-base-content/60">As of Today</p>
            </div>

            <%!-- Assets --%>
            <div class="space-y-2">
              <h3 class="font-extrabold text-xs uppercase tracking-wider text-primary border-b border-base-200 pb-1">
                ASSETS
              </h3>
              <%= for asset <- @balance_sheet.assets do %>
                <div class="flex justify-between text-sm py-1">
                  <span>{asset.code} - {asset.name}</span>
                  <span class="font-medium">KES {format_money(asset.amount)}</span>
                </div>
              <% end %>
              <div class="flex justify-between font-black text-base border-t border-base-200 pt-2 text-primary">
                <span>TOTAL ASSETS</span>
                <span>KES {format_money(@balance_sheet.total_assets)}</span>
              </div>
            </div>

            <%!-- Liabilities --%>
            <div class="space-y-2">
              <h3 class="font-extrabold text-xs uppercase tracking-wider text-warning border-b border-base-200 pb-1">
                LIABILITIES
              </h3>
              <%= for liab <- @balance_sheet.liabilities do %>
                <div class="flex justify-between text-sm py-1">
                  <span>{liab.code} - {liab.name}</span>
                  <span class="font-medium">KES {format_money(liab.amount)}</span>
                </div>
              <% end %>
              <div class="flex justify-between font-bold text-sm border-t border-base-200 pt-2 text-warning">
                <span>TOTAL LIABILITIES</span>
                <span>KES {format_money(@balance_sheet.total_liabilities)}</span>
              </div>
            </div>

            <%!-- Equity --%>
            <div class="space-y-2">
              <h3 class="font-extrabold text-xs uppercase tracking-wider text-accent border-b border-base-200 pb-1">
                EQUITY
              </h3>
              <%= for eq <- @balance_sheet.equity do %>
                <div class="flex justify-between text-sm py-1">
                  <span>{eq.code} - {eq.name}</span>
                  <span class="font-medium">KES {format_money(eq.amount)}</span>
                </div>
              <% end %>
              <div class="flex justify-between text-sm py-1 text-success font-medium">
                <span>Current Period Net Income</span>
                <span>KES {format_money(@balance_sheet.net_income)}</span>
              </div>
              <div class="flex justify-between font-bold text-sm border-t border-base-200 pt-2 text-accent">
                <span>TOTAL EQUITY</span>
                <span>KES {format_money(@balance_sheet.total_equity)}</span>
              </div>
            </div>

            <%!-- Check Balance Equation --%>
            <div class="bg-base-200/80 p-4 rounded-xl flex items-center justify-between font-black text-base border border-base-300">
              <span>TOTAL LIABILITIES & EQUITY</span>
              <span class="text-primary">
                KES {format_money(@balance_sheet.total_liabilities_and_equity)}
              </span>
            </div>
          </div>
        <% end %>

        <%!-- TAB 3: Chart of Accounts --%>
        <%= if @active_tab == "chart_of_accounts" do %>
          <div class="bg-base-100 border border-base-300 rounded-2xl overflow-hidden shadow-xs">
            <div class="overflow-x-auto">
              <table class="table table-zebra w-full text-left">
                <thead class="bg-base-200/50 text-xs font-bold uppercase tracking-wider text-base-content/70">
                  <tr>
                    <th class="py-3 px-4">Code</th>
                    <th class="py-3 px-4">Account Name</th>
                    <th class="py-3 px-4">Type</th>
                    <th class="py-3 px-4 text-right">Current Ledger Balance</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for acc <- @accounts do %>
                    <tr class="hover:bg-base-200/40">
                      <td class="font-mono font-bold text-sm text-primary py-3.5 px-4">
                        {acc.code}
                      </td>
                      <td class="font-bold text-sm text-base-content py-3.5 px-4">
                        {acc.name}
                      </td>
                      <td class="py-3.5 px-4">
                        <span class={[
                          "badge badge-sm font-bold uppercase",
                          if(acc.type == "asset", do: "badge-primary"),
                          if(acc.type == "liability", do: "badge-warning"),
                          if(acc.type == "equity", do: "badge-accent"),
                          if(acc.type == "revenue", do: "badge-success"),
                          if(acc.type == "expense", do: "badge-error")
                        ]}>
                          {acc.type}
                        </span>
                      </td>
                      <td class="font-black text-sm text-right py-3.5 px-4">
                        KES {format_money(acc.balance)}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_money(nil), do: "0.00"

  defp format_money(val) do
    val
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end
end
