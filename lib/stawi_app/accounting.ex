defmodule StawiApp.Accounting do
  @moduledoc """
  The Accounting context for managing Chart of Accounts and Double-Entry General Ledger.
  """
  import Ecto.Query, warn: false
  alias StawiApp.Repo
  alias StawiApp.Accounting.{Account, JournalEntry}

  # --- ACCOUNTS ---

  def list_accounts do
    Account
    |> order_by([a], asc: a.code)
    |> Repo.all()
  end

  def get_account!(id), do: Repo.get!(Account, id)

  def get_account_by_code(code), do: Repo.get_by(Account, code: code)

  def create_account(attrs \\ %{}) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  def change_account(%Account{} = account, attrs \\ %{}) do
    Account.changeset(account, attrs)
  end

  # --- JOURNAL ENTRIES ---

  def list_journal_entries do
    JournalEntry
    |> order_by([j], desc: j.entry_date, desc: j.inserted_at)
    |> Repo.all()
    |> Repo.preload(journal_lines: :account)
  end

  def get_journal_entry!(id) do
    JournalEntry
    |> Repo.get!(id)
    |> Repo.preload(journal_lines: :account)
  end

  @doc """
  Posts a balanced double-entry journal entry and updates corresponding account balances atomically.
  """
  def post_journal_entry(attrs) do
    entry_changeset = JournalEntry.changeset(%JournalEntry{}, attrs)

    if entry_changeset.valid? do
      lines = Ecto.Changeset.get_field(entry_changeset, :journal_lines) || []

      debits =
        lines
        |> Enum.filter(&(&1.type == "debit"))
        |> Enum.reduce(Decimal.new("0.0"), fn line, acc -> Decimal.add(acc, line.amount) end)

      credits =
        lines
        |> Enum.filter(&(&1.type == "credit"))
        |> Enum.reduce(Decimal.new("0.0"), fn line, acc -> Decimal.add(acc, line.amount) end)

      if Decimal.equal?(debits, credits) and Decimal.gt?(debits, Decimal.new("0")) do
        Repo.transaction(fn ->
          case Repo.insert(entry_changeset) do
            {:ok, entry} ->
              # Update account balances based on account types
              Enum.each(lines, fn line ->
                account = Repo.get!(Account, line.account_id)
                # Asset & Expense increase with Debits, decrease with Credits
                # Liability, Equity & Revenue increase with Credits, decrease with Debits
                new_balance =
                  case {account.type, line.type} do
                    {type, "debit"} when type in ["asset", "expense"] ->
                      Decimal.add(account.balance, line.amount)

                    {type, "credit"} when type in ["asset", "expense"] ->
                      Decimal.sub(account.balance, line.amount)

                    {type, "credit"} when type in ["liability", "equity", "revenue"] ->
                      Decimal.add(account.balance, line.amount)

                    {type, "debit"} when type in ["liability", "equity", "revenue"] ->
                      Decimal.sub(account.balance, line.amount)
                  end

                account
                |> Account.changeset(%{balance: new_balance})
                |> Repo.update!()
              end)

              entry

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end)
      else
        {:error,
         Ecto.Changeset.add_error(
           entry_changeset,
           :journal_lines,
           "Total debits must equal total credits and be greater than 0"
         )}
      end
    else
      {:error, entry_changeset}
    end
  end
end
