defmodule StawiApp.Sales do
  @moduledoc """
  The Sales context managing Walk-In Checkout, Sales Log, Customers, and Accounting integration.
  """
  import Ecto.Query, warn: false
  alias StawiApp.Repo
  alias StawiApp.Sales.{Customer, Sale}
  alias StawiApp.Accounting
  alias StawiApp.Inventory

  # --- CUSTOMERS ---

  def list_customers do
    Customer
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  def get_customer(id) when is_nil(id), do: nil
  def get_customer(id), do: Repo.get(Customer, id)

  def get_customer!(id), do: Repo.get!(Customer, id)

  def create_customer(attrs \\ %{}) do
    %Customer{}
    |> Customer.changeset(attrs)
    |> Repo.insert()
  end

  def update_customer(%Customer{} = customer, attrs) do
    customer
    |> Customer.changeset(attrs)
    |> Repo.update()
  end

  def change_customer(%Customer{} = customer, attrs \\ %{}) do
    Customer.changeset(customer, attrs)
  end

  # --- SALES ---

  def list_sales do
    Sale
    |> order_by([s], desc: s.sale_date, desc: s.inserted_at)
    |> Repo.all()
    |> Repo.preload([:customer, sale_items: :product])
  end

  def get_sale!(id) do
    Sale
    |> Repo.get!(id)
    |> Repo.preload([:customer, sale_items: :product])
  end

  def change_sale(%Sale{} = sale, attrs \\ %{}) do
    Sale.changeset(sale, attrs)
  end

  def generate_sale_number do
    count = Repo.aggregate(Sale, :count, :id) || 0
    "SALE-" <> String.pad_leading(to_string(count + 1), 5, "0")
  end

  @doc """
  Records a complete walk-in sale:
  1. Inserts Sale & SaleItems
  2. Updates Product inventory counts
  3. Updates Customer credit balance if credit sale
  4. Automatically posts balanced double-entry JournalEntry to General Ledger
  """
  def record_sale(attrs) do
    sale_number = attrs["sale_number"] || generate_sale_number()
    sale_date = attrs["sale_date"] || DateTime.utc_now()

    attrs_with_defaults =
      attrs
      |> Map.put("sale_number", sale_number)
      |> Map.put("sale_date", sale_date)

    changeset = Sale.changeset(%Sale{}, attrs_with_defaults)

    if changeset.valid? do
      Repo.transaction(fn ->
        case Repo.insert(changeset) do
          {:ok, sale} ->
            sale = Repo.preload(sale, sale_items: :product, customer: [])

            # 1. Update Product Inventory
            Enum.each(sale.sale_items, fn item ->
              Inventory.update_stock_quantity(item.product_id, -item.quantity)
            end)

            # 2. Update Customer Balance if credit / unpaid
            if sale.customer_id &&
                 Decimal.gt?(Decimal.sub(sale.total_amount, sale.paid_amount), Decimal.new("0")) do
              customer = Repo.get!(Customer, sale.customer_id)
              unpaid = Decimal.sub(sale.total_amount, sale.paid_amount)
              update_customer(customer, %{balance: Decimal.add(customer.balance, unpaid)})
            end

            # 3. Double-Entry Accounting Journal Posting
            post_sale_journal_entry(sale)

            sale

          {:error, cs} ->
            Repo.rollback(cs)
        end
      end)
    else
      {:error, changeset}
    end
  end

  defp post_sale_journal_entry(sale) do
    # Cash Box
    cash_acc = Accounting.get_account_by_code("1010")
    # M-Pesa / Mobile Money
    mpesa_acc = Accounting.get_account_by_code("1020")
    # Bank Account
    bank_acc = Accounting.get_account_by_code("1030")
    # Accounts Receivable
    ar_acc = Accounting.get_account_by_code("1100")
    # Sales Revenue
    revenue_acc = Accounting.get_account_by_code("4010")
    # Cost of Goods Sold
    cogs_acc = Accounting.get_account_by_code("5010")
    # Inventory Asset
    inventory_acc = Accounting.get_account_by_code("1200")

    payment_acc =
      case sale.payment_method do
        "mpesa" -> mpesa_acc || cash_acc
        "bank" -> bank_acc || cash_acc
        _ -> cash_acc
      end

    lines = []

    # Debit Received Payment (Cash/M-Pesa/Bank)
    lines =
      if Decimal.gt?(sale.paid_amount, Decimal.new("0")) && payment_acc do
        lines ++ [%{account_id: payment_acc.id, type: "debit", amount: sale.paid_amount}]
      else
        lines
      end

    # Debit Accounts Receivable for unpaid portion
    unpaid = Decimal.sub(sale.total_amount, sale.paid_amount)

    lines =
      if Decimal.gt?(unpaid, Decimal.new("0")) && ar_acc do
        lines ++ [%{account_id: ar_acc.id, type: "debit", amount: unpaid}]
      else
        lines
      end

    # Credit Revenue Account for Total Amount
    lines =
      if revenue_acc do
        lines ++ [%{account_id: revenue_acc.id, type: "credit", amount: sale.total_amount}]
      else
        lines
      end

    # COGS & Inventory Asset Entry
    total_cogs =
      Enum.reduce(sale.sale_items, Decimal.new("0.0"), fn item, acc ->
        cost = item.product.cost_price || Decimal.new("0.0")
        Decimal.add(acc, Decimal.mult(cost, Decimal.new(item.quantity)))
      end)

    lines =
      if Decimal.gt?(total_cogs, Decimal.new("0")) && cogs_acc && inventory_acc do
        lines ++
          [
            %{account_id: cogs_acc.id, type: "debit", amount: total_cogs},
            %{account_id: inventory_acc.id, type: "credit", amount: total_cogs}
          ]
      else
        lines
      end

    if lines != [] do
      Accounting.post_journal_entry(%{
        entry_date: Date.utc_today(),
        reference: sale.sale_number,
        description: "POS Sale #{sale.sale_number}",
        journal_lines: lines
      })
    end
  end
end
