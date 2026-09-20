# Script for populating the database with Chart of Accounts, Products, Sales, Expenses, and Customers.

alias StawiApp.Repo
alias StawiApp.Accounting
alias StawiApp.Inventory
alias StawiApp.Sales
alias StawiApp.Expenses

IO.puts("--> Seeding Chart of Accounts...")

accounts_data = [
  %{code: "1010", name: "Cash Box", type: "asset", is_system: true},
  %{code: "1020", name: "M-Pesa / Mobile Money", type: "asset", is_system: true},
  %{code: "1030", name: "Bank Account", type: "asset", is_system: true},
  %{code: "1100", name: "Accounts Receivable", type: "asset", is_system: true},
  %{code: "1200", name: "Inventory Asset", type: "asset", is_system: true},
  %{code: "2010", name: "Accounts Payable", type: "liability", is_system: true},
  %{code: "2020", name: "Sales Tax Payable", type: "liability", is_system: true},
  %{code: "3010", name: "Owner's Capital", type: "equity", is_system: true},
  %{code: "3020", name: "Retained Earnings", type: "equity", is_system: true},
  %{code: "4010", name: "Product Sales Revenue", type: "revenue", is_system: true},
  %{code: "4020", name: "Service Revenue", type: "revenue", is_system: true},
  %{code: "5010", name: "Cost of Goods Sold (COGS)", type: "expense", is_system: true},
  %{code: "5020", name: "Rent Expense", type: "expense", is_system: false},
  %{code: "5030", name: "Utilities (Power & Water)", type: "expense", is_system: false},
  %{code: "5040", name: "Salaries & Wages", type: "expense", is_system: false},
  %{code: "5050", name: "Transport & Logistics", type: "expense", is_system: false},
  %{code: "5060", name: "General & Miscellaneous Expenses", type: "expense", is_system: false}
]

for acc <- accounts_data do
  unless Accounting.get_account_by_code(acc.code) do
    Accounting.create_account(acc)
  end
end

IO.puts("--> Seeding Initial Owner Capital (Starting Cash & Bank)...")

cash_acc = Accounting.get_account_by_code("1010")
mpesa_acc = Accounting.get_account_by_code("1020")
capital_acc = Accounting.get_account_by_code("3010")

if cash_acc && mpesa_acc && capital_acc do
  # Post initial capital deposit if no journal entries exist
  if Accounting.list_journal_entries() == [] do
    Accounting.post_journal_entry(%{
      entry_date: Date.utc_today(),
      reference: "INIT-001",
      description: "Initial Owner Capital Deposit",
      journal_lines: [
        %{account_id: cash_acc.id, type: "debit", amount: Decimal.new("15000.00")},
        %{account_id: mpesa_acc.id, type: "debit", amount: Decimal.new("25000.00")},
        %{account_id: capital_acc.id, type: "credit", amount: Decimal.new("40000.00")}
      ]
    })
  end
end

IO.puts("--> Seeding Sample Products & Inventory...")

products_data = [
  %{
    name: "Maize Flour 2kg",
    sku: "FLR-001",
    category: "Groceries",
    unit_price: "220.00",
    cost_price: "175.00",
    stock_quantity: 45,
    min_stock_level: 10,
    unit: "bag"
  },
  %{
    name: "Cooking Oil 1 Litre",
    sku: "OIL-001",
    category: "Groceries",
    unit_price: "340.00",
    cost_price: "285.00",
    stock_quantity: 30,
    min_stock_level: 8,
    unit: "bottle"
  },
  %{
    name: "White Sugar 1kg",
    sku: "SGR-001",
    category: "Groceries",
    unit_price: "160.00",
    cost_price: "130.00",
    stock_quantity: 50,
    min_stock_level: 15,
    unit: "pack"
  },
  %{
    name: "Basmati Rice 5kg",
    sku: "RCE-005",
    category: "Groceries",
    unit_price: "1150.00",
    cost_price: "920.00",
    stock_quantity: 18,
    min_stock_level: 5,
    unit: "bag"
  },
  %{
    name: "Bar Soap 800g",
    sku: "SOP-001",
    category: "Household",
    unit_price: "180.00",
    cost_price: "140.00",
    stock_quantity: 4,
    min_stock_level: 10,
    unit: "pcs"
  },
  %{
    name: "Drinking Water 500ml",
    sku: "WTR-500",
    category: "Beverages",
    unit_price: "50.00",
    cost_price: "32.00",
    stock_quantity: 60,
    min_stock_level: 20,
    unit: "bottle"
  },
  %{
    name: "Black Tea Bags 100s",
    sku: "TEA-100",
    category: "Beverages",
    unit_price: "290.00",
    cost_price: "220.00",
    stock_quantity: 2,
    min_stock_level: 5,
    unit: "box"
  }
]

inserted_products =
  for p <- products_data do
    case Repo.get_by(Inventory.Product, sku: p.sku) do
      nil ->
        {:ok, product} = Inventory.create_product(p)
        product

      existing ->
        existing
    end
  end

IO.puts("--> Seeding Sample Customers...")

customers_data = [
  %{name: "Jane Wanjiku", phone: "+254712345678", email: "jane@example.com"},
  %{name: "Mama Otis Eatery", phone: "+254722998877", email: "otis@example.com"},
  %{name: "Kiprono Stores", phone: "+254733445566", email: "kiprono@example.com"}
]

inserted_customers =
  for c <- customers_data do
    case Repo.get_by(Sales.Customer, name: c.name) do
      nil ->
        {:ok, customer} = Sales.create_customer(c)
        customer

      existing ->
        existing
    end
  end

IO.puts("--> Seeding Initial Walk-In POS Sales...")

if Sales.list_sales() == [] do
  p1 = Enum.at(inserted_products, 0)
  p2 = Enum.at(inserted_products, 1)
  p3 = Enum.at(inserted_products, 2)
  cust = Enum.at(inserted_customers, 0)

  # Sale 1: Walk-In Cash Sale
  Sales.record_sale(%{
    "sale_number" => "SALE-00001",
    "total_amount" => Decimal.new("560.00"),
    "paid_amount" => Decimal.new("560.00"),
    "payment_status" => "paid",
    "payment_method" => "cash",
    "sale_date" => DateTime.utc_now(),
    "sale_items" => [
      %{
        "product_id" => p1.id,
        "quantity" => 1,
        "unit_price" => p1.unit_price,
        "subtotal" => Decimal.new("220.00")
      },
      %{
        "product_id" => p2.id,
        "quantity" => 1,
        "unit_price" => p2.unit_price,
        "subtotal" => Decimal.new("340.00")
      }
    ]
  })

  # Sale 2: M-Pesa Sale
  Sales.record_sale(%{
    "sale_number" => "SALE-00002",
    "total_amount" => Decimal.new("1470.00"),
    "paid_amount" => Decimal.new("1470.00"),
    "payment_status" => "paid",
    "payment_method" => "mpesa",
    "sale_date" => DateTime.utc_now(),
    "sale_items" => [
      %{
        "product_id" => p2.id,
        "quantity" => 1,
        "unit_price" => p2.unit_price,
        "subtotal" => Decimal.new("340.00")
      },
      %{
        "product_id" => p3.id,
        "quantity" => 2,
        "unit_price" => p3.unit_price,
        "subtotal" => Decimal.new("320.00")
      },
      %{
        "product_id" => p1.id,
        "quantity" => 3,
        "unit_price" => p1.unit_price,
        "subtotal" => Decimal.new("660.00")
      },
      %{
        "product_id" => Enum.at(inserted_products, 5).id,
        "quantity" => 3,
        "unit_price" => Decimal.new("50.00"),
        "subtotal" => Decimal.new("150.00")
      }
    ]
  })

  # Sale 3: Credit Sale with Customer Link
  Sales.record_sale(%{
    "sale_number" => "SALE-00003",
    "customer_id" => cust.id,
    "total_amount" => Decimal.new("1150.00"),
    "paid_amount" => Decimal.new("500.00"),
    "payment_status" => "partial",
    "payment_method" => "credit",
    "sale_date" => DateTime.utc_now(),
    "sale_items" => [
      %{
        "product_id" => Enum.at(inserted_products, 3).id,
        "quantity" => 1,
        "unit_price" => Decimal.new("1150.00"),
        "subtotal" => Decimal.new("1150.00")
      }
    ]
  })
end

IO.puts("--> Seeding Sample Expenses...")

if Expenses.list_expenses() == [] do
  Expenses.record_expense(%{
    "date" => Date.utc_today(),
    "description" => "Shop Rent for Current Month",
    "category" => "rent",
    "amount" => Decimal.new("8000.00"),
    "payment_method" => "mpesa",
    "receipt_ref" => "MPESA-RENT-8000"
  })

  Expenses.record_expense(%{
    "date" => Date.utc_today(),
    "description" => "Electricity & Water Token",
    "category" => "utilities",
    "amount" => Decimal.new("1200.00"),
    "payment_method" => "cash",
    "receipt_ref" => "KPLC-1200"
  })
end

IO.puts("--> Stawi App database seeding complete!")
