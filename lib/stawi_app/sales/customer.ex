defmodule StawiApp.Sales.Customer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "customers" do
    field :name, :string
    field :phone, :string
    field :email, :string
    field :balance, :decimal, default: Decimal.new("0.0")

    has_many :sales, StawiApp.Sales.Sale

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [:name, :phone, :email, :balance])
    |> validate_required([:name])
  end
end
