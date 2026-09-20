defmodule StawiApp.Repo.Migrations.CreateAccountingSalesAndInventory do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :type, :string, null: false
      add :balance, :decimal, precision: 12, scale: 2, default: 0.0, null: false
      add :is_system, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:accounts, [:code])

    create table(:journal_entries) do
      add :entry_date, :date, null: false
      add :reference, :string
      add :description, :text
      add :status, :string, default: "posted", null: false

      timestamps(type: :utc_datetime)
    end

    create table(:journal_lines) do
      add :journal_entry_id, references(:journal_entries, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :restrict), null: false
      add :type, :string, null: false
      add :amount, :decimal, precision: 12, scale: 2, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:journal_lines, [:journal_entry_id])
    create index(:journal_lines, [:account_id])

    create table(:products) do
      add :name, :string, null: false
      add :sku, :string
      add :category, :string, default: "General"
      add :unit_price, :decimal, precision: 12, scale: 2, default: 0.0, null: false
      add :cost_price, :decimal, precision: 12, scale: 2, default: 0.0, null: false
      add :stock_quantity, :integer, default: 0, null: false
      add :min_stock_level, :integer, default: 5, null: false
      add :unit, :string, default: "pcs"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:products, [:sku])

    create table(:customers) do
      add :name, :string, null: false
      add :phone, :string
      add :email, :string
      add :balance, :decimal, precision: 12, scale: 2, default: 0.0, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:sales) do
      add :sale_number, :string, null: false
      add :customer_id, references(:customers, on_delete: :nilify_all)
      add :total_amount, :decimal, precision: 12, scale: 2, null: false
      add :discount_amount, :decimal, precision: 12, scale: 2, default: 0.0
      add :paid_amount, :decimal, precision: 12, scale: 2, default: 0.0
      add :payment_status, :string, default: "paid", null: false
      add :payment_method, :string, default: "cash", null: false
      add :sale_date, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sales, [:sale_number])
    create index(:sales, [:customer_id])

    create table(:sale_items) do
      add :sale_id, references(:sales, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :restrict), null: false
      add :quantity, :integer, null: false
      add :unit_price, :decimal, precision: 12, scale: 2, null: false
      add :subtotal, :decimal, precision: 12, scale: 2, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sale_items, [:sale_id])
    create index(:sale_items, [:product_id])

    create table(:expenses) do
      add :date, :date, null: false
      add :description, :string, null: false
      add :category, :string, null: false
      add :amount, :decimal, precision: 12, scale: 2, null: false
      add :payment_method, :string, default: "cash", null: false
      add :account_id, references(:accounts, on_delete: :nilify_all)
      add :receipt_ref, :string

      timestamps(type: :utc_datetime)
    end

    create index(:expenses, [:account_id])
  end
end
