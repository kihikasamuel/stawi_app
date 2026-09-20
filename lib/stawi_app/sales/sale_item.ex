defmodule StawiApp.Sales.SaleItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sale_items" do
    field :quantity, :integer
    field :unit_price, :decimal
    field :subtotal, :decimal

    belongs_to :sale, StawiApp.Sales.Sale
    belongs_to :product, StawiApp.Inventory.Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sale_item, attrs) do
    sale_item
    |> cast(attrs, [:sale_id, :product_id, :quantity, :unit_price, :subtotal])
    |> validate_required([:product_id, :quantity, :unit_price, :subtotal])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
  end
end
