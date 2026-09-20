defmodule StawiApp.Accounting.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :code, :string
    field :name, :string
    # asset, liability, equity, revenue, expense
    field :type, :string
    field :balance, :decimal, default: Decimal.new("0.0")
    field :is_system, :boolean, default: false

    has_many :journal_lines, StawiApp.Accounting.JournalLine

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:code, :name, :type, :balance, :is_system])
    |> validate_required([:code, :name, :type])
    |> validate_inclusion(:type, ["asset", "liability", "equity", "revenue", "expense"])
    |> unique_constraint(:code)
  end
end
