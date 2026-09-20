defmodule StawiApp.Accounting.JournalLine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "journal_lines" do
    # debit, credit
    field :type, :string
    field :amount, :decimal

    belongs_to :journal_entry, StawiApp.Accounting.JournalEntry
    belongs_to :account, StawiApp.Accounting.Account

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(journal_line, attrs) do
    journal_line
    |> cast(attrs, [:journal_entry_id, :account_id, :type, :amount])
    |> validate_required([:account_id, :type, :amount])
    |> validate_inclusion(:type, ["debit", "credit"])
    |> validate_number(:amount, greater_than: 0)
  end
end
