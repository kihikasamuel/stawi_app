defmodule StawiApp.Expenses do
  @moduledoc """
  The Expenses context managing SME expense logging and accounting integration.
  """
  import Ecto.Query, warn: false
  alias StawiApp.Repo
  alias StawiApp.Expenses.Expense
  alias StawiApp.Accounting

  def list_expenses do
    Expense
    |> order_by([e], desc: e.date, desc: e.inserted_at)
    |> Repo.all()
    |> Repo.preload(:account)
  end

  def get_expense!(id) do
    Expense
    |> Repo.get!(id)
    |> Repo.preload(:account)
  end

  def change_expense(%Expense{} = expense, attrs \\ %{}) do
    Expense.changeset(expense, attrs)
  end

  def record_expense(attrs) do
    changeset = Expense.changeset(%Expense{}, attrs)

    if changeset.valid? do
      Repo.transaction(fn ->
        case Repo.insert(changeset) do
          {:ok, expense} ->
            post_expense_journal_entry(expense)
            expense

          {:error, cs} ->
            Repo.rollback(cs)
        end
      end)
    else
      {:error, changeset}
    end
  end

  defp post_expense_journal_entry(expense) do
    # Cash Box
    cash_acc = Accounting.get_account_by_code("1010")
    # M-Pesa / Mobile Money
    mpesa_acc = Accounting.get_account_by_code("1020")
    # Bank Account
    bank_acc = Accounting.get_account_by_code("1030")

    # Map expense category to expense account code
    expense_account_code =
      case String.downcase(expense.category) do
        "rent" -> "5020"
        "utilities" -> "5030"
        "salaries" -> "5040"
        "transport" -> "5050"
        # General Expenses
        _ -> "5060"
      end

    exp_acc =
      Accounting.get_account_by_code(expense_account_code) ||
        Accounting.get_account_by_code("5060")

    payment_acc =
      case expense.payment_method do
        "mpesa" -> mpesa_acc || cash_acc
        "bank" -> bank_acc || cash_acc
        _ -> cash_acc
      end

    if exp_acc && payment_acc do
      Accounting.post_journal_entry(%{
        entry_date: expense.date || Date.utc_today(),
        reference: expense.receipt_ref || "EXP-#{expense.id}",
        description: "Expense: #{expense.description} (#{expense.category})",
        journal_lines: [
          %{account_id: exp_acc.id, type: "debit", amount: expense.amount},
          %{account_id: payment_acc.id, type: "credit", amount: expense.amount}
        ]
      })
    end
  end
end
