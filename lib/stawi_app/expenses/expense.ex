defmodule StawiApp.Expenses.Expense do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expenses" do
    field :date, :date
    field :description, :string
    field :category, :string
    field :amount, :decimal
    # cash, mpesa, bank
    field :payment_method, :string, default: "cash"
    field :receipt_ref, :string

    belongs_to :account, StawiApp.Accounting.Account

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(expense, attrs) do
    expense
    |> cast(attrs, [
      :date,
      :description,
      :category,
      :amount,
      :payment_method,
      :account_id,
      :receipt_ref
    ])
    |> validate_required([:date, :description, :category, :amount, :payment_method])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:payment_method, ["cash", "mpesa", "bank"])
  end
end
