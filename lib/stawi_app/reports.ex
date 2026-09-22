defmodule StawiApp.Reports do
  @moduledoc """
  The Reports context providing SME analytical engines:
  - Dashboard KPIs
  - Income Statement (Profit & Loss)
  - Balance Sheet
  - Sales & Inventory Analytics
  """
  import Ecto.Query, warn: false
  alias StawiApp.Repo
  alias StawiApp.Accounting
  alias StawiApp.Sales.Sale
  alias StawiApp.Expenses.Expense
  alias StawiApp.Inventory.Product

  def dashboard_summary do
    today = Date.utc_today()
    beginning_of_month = Date.beginning_of_month(today)

    # Today's Sales
    today_sales =
      Sale
      |> where([s], fragment("?::date", s.sale_date) == ^today)
      |> select([s], %{
        count: count(s.id),
        total: coalesce(sum(s.total_amount), 0.0)
      })
      |> Repo.one() || %{count: 0, total: Decimal.new("0.0")}

    # Monthly Sales
    month_sales =
      Sale
      |> where([s], fragment("?::date", s.sale_date) >= ^beginning_of_month)
      |> select([s], coalesce(sum(s.total_amount), 0))
      |> Repo.one()
      |> to_decimal()

    # Monthly Expenses
    month_expenses =
      Expense
      |> where([e], e.date >= ^beginning_of_month)
      |> select([e], coalesce(sum(e.amount), 0))
      |> Repo.one()
      |> to_decimal()

    # Net Profit for the Month
    month_net_profit = Decimal.sub(month_sales, month_expenses)

    # Account Balances
    accounts = Accounting.list_accounts()

    # Cash
    cash_balance = get_account_sum(accounts, "1010")
    # M-Pesa
    mpesa_balance = get_account_sum(accounts, "1020")
    # Bank
    bank_balance = get_account_sum(accounts, "1030")
    # Receivables
    ar_balance = get_account_sum(accounts, "1100")
    # Inventory Value
    inventory_val = get_account_sum(accounts, "1200")

    # Low Stock Items Count
    low_stock_count =
      Product
      |> where([p], p.stock_quantity <= p.min_stock_level)
      |> select([p], count(p.id))
      |> Repo.one() || 0

    %{
      today_sales_count: today_sales.count,
      today_sales_total: today_sales.total,
      month_sales: month_sales,
      month_expenses: month_expenses,
      month_net_profit: month_net_profit,
      cash_balance: cash_balance,
      mpesa_balance: mpesa_balance,
      bank_balance: bank_balance,
      ar_balance: ar_balance,
      inventory_value: inventory_val,
      low_stock_count: low_stock_count
    }
  end

  def income_statement do
    accounts = Accounting.list_accounts()

    revenues =
      accounts
      |> Enum.filter(&(&1.type == "revenue"))
      |> Enum.map(&%{name: &1.name, code: &1.code, amount: &1.balance})

    total_revenue =
      Enum.reduce(revenues, Decimal.new("0.0"), fn r, acc -> Decimal.add(acc, r.amount) end)

    cogs_account = Accounting.get_account_by_code("5010")
    cogs_amount = if cogs_account, do: cogs_account.balance, else: Decimal.new("0.0")

    gross_profit = Decimal.sub(total_revenue, cogs_amount)

    expenses =
      accounts
      |> Enum.filter(&(&1.type == "expense" and &1.code != "5010"))
      |> Enum.map(&%{name: &1.name, code: &1.code, amount: &1.balance})

    total_expenses =
      Enum.reduce(expenses, Decimal.new("0.0"), fn e, acc -> Decimal.add(acc, e.amount) end)

    net_income = Decimal.sub(gross_profit, total_expenses)

    %{
      revenues: revenues,
      total_revenue: total_revenue,
      cogs: cogs_amount,
      gross_profit: gross_profit,
      expenses: expenses,
      total_expenses: total_expenses,
      net_income: net_income
    }
  end

  def balance_sheet do
    accounts = Accounting.list_accounts()

    assets =
      accounts
      |> Enum.filter(&(&1.type == "asset"))
      |> Enum.map(&%{name: &1.name, code: &1.code, amount: &1.balance})

    total_assets =
      Enum.reduce(assets, Decimal.new("0.0"), fn a, acc -> Decimal.add(acc, a.amount) end)

    liabilities =
      accounts
      |> Enum.filter(&(&1.type == "liability"))
      |> Enum.map(&%{name: &1.name, code: &1.code, amount: &1.balance})

    total_liabilities =
      Enum.reduce(liabilities, Decimal.new("0.0"), fn l, acc -> Decimal.add(acc, l.amount) end)

    equity_accounts =
      accounts
      |> Enum.filter(&(&1.type == "equity"))
      |> Enum.map(&%{name: &1.name, code: &1.code, amount: &1.balance})

    # Add Net Income to Equity
    income_stmt = income_statement()
    net_income = income_stmt.net_income

    equity_total_accounts =
      Enum.reduce(equity_accounts, Decimal.new("0.0"), fn e, acc -> Decimal.add(acc, e.amount) end)

    total_equity = Decimal.add(equity_total_accounts, net_income)

    total_liabilities_and_equity = Decimal.add(total_liabilities, total_equity)

    %{
      assets: assets,
      total_assets: total_assets,
      liabilities: liabilities,
      total_liabilities: total_liabilities,
      equity: equity_accounts,
      net_income: net_income,
      total_equity: total_equity,
      total_liabilities_and_equity: total_liabilities_and_equity
    }
  end

  defp get_account_sum(accounts, code) do
    case Enum.find(accounts, &(&1.code == code)) do
      nil -> Decimal.new("0.0")
      acc -> acc.balance
    end
  end

  defp to_decimal(%Decimal{} = val), do: val
  defp to_decimal(val) when is_integer(val), do: Decimal.new(val)
  defp to_decimal(val) when is_float(val), do: Decimal.from_float(val)
  defp to_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp to_decimal(_), do: Decimal.new("0")
end
