defmodule StawiApp.Inventory.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :sku, :string
    field :category, :string, default: "General"
    field :unit_price, :decimal, default: Decimal.new("0.0")
    field :cost_price, :decimal, default: Decimal.new("0.0")
    field :stock_quantity, :integer, default: 0
    field :min_stock_level, :integer, default: 5
    field :unit, :string, default: "pcs"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :name,
      :sku,
      :category,
      :unit_price,
      :cost_price,
      :stock_quantity,
      :min_stock_level,
      :unit
    ])
    |> validate_required([:name, :unit_price, :cost_price])
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> validate_number(:cost_price, greater_than_or_equal_to: 0)
    |> validate_number(:stock_quantity, greater_than_or_equal_to: 0)
    |> unique_constraint(:sku)
  end
end
