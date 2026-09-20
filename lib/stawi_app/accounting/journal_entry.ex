defmodule StawiApp.Accounting.JournalEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "journal_entries" do
    field :entry_date, :date
    field :reference, :string
    field :description, :string
    field :status, :string, default: "posted"

    has_many :journal_lines, StawiApp.Accounting.JournalLine, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(journal_entry, attrs) do
    journal_entry
    |> cast(attrs, [:entry_date, :reference, :description, :status])
    |> validate_required([:entry_date, :description])
    |> cast_assoc(:journal_lines, required: true)
  end
end
