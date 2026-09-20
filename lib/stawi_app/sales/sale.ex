defmodule StawiApp.Sales.Sale do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sales" do
    field :sale_number, :string
    field :total_amount, :decimal
    field :discount_amount, :decimal, default: Decimal.new("0.0")
    field :paid_amount, :decimal, default: Decimal.new("0.0")
    # paid, partial, unpaid
    field :payment_status, :string, default: "paid"
    # cash, mpesa, bank, credit
    field :payment_method, :string, default: "cash"
    field :sale_date, :utc_datetime

    belongs_to :customer, StawiApp.Sales.Customer
    has_many :sale_items, StawiApp.Sales.SaleItem, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sale, attrs) do
    sale
    |> cast(attrs, [
      :sale_number,
      :customer_id,
      :total_amount,
      :discount_amount,
      :paid_amount,
      :payment_status,
      :payment_method,
      :sale_date
    ])
    |> validate_required([
      :sale_number,
      :total_amount,
      :payment_status,
      :payment_method,
      :sale_date
    ])
    |> validate_inclusion(:payment_status, ["paid", "partial", "unpaid"])
    |> validate_inclusion(:payment_method, ["cash", "mpesa", "bank", "credit"])
    |> cast_assoc(:sale_items, required: true)
    |> unique_constraint(:sale_number)
  end
end
