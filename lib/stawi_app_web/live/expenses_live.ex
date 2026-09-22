defmodule StawiAppWeb.ExpensesLive do
  use StawiAppWeb, :live_view

  alias StawiApp.Expenses
  alias StawiApp.Expenses.Expense

  @impl true
  def mount(_params, _session, socket) do
    expenses = Expenses.list_expenses()

    {:ok,
     socket
     |> assign(:expenses_list, expenses)
     |> assign(:show_modal, false)
     |> assign(:expense_form, to_form(Expenses.change_expense(%Expense{date: Date.utc_today()})))
     |> stream(:expenses, expenses)}
  end

  @impl true
  def handle_event("open_new_modal", _params, socket) do
    changeset = Expenses.change_expense(%Expense{date: Date.utc_today()})
    {:noreply, assign(socket, expense_form: to_form(changeset), show_modal: true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  @impl true
  def handle_event("save_expense", %{"expense" => params}, socket) do
    case Expenses.record_expense(params) do
      {:ok, _expense} ->
        updated = Expenses.list_expenses()

        {:noreply,
         socket
         |> assign(:expenses_list, updated)
         |> stream(:expenses, updated, reset: true)
         |> assign(:show_modal, false)
         |> put_flash(:info, "Expense logged and posted to General Ledger!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :expense_form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-base-100 p-5 rounded-2xl border border-base-300 shadow-xs">
          <div>
            <h1 class="text-2xl font-black tracking-tight text-base-content flex items-center gap-2">
              <.icon name="hero-banknotes" class="w-6 h-6 text-warning" /> Business Expense Tracker
            </h1>
            <p class="text-sm text-base-content/70 mt-0.5">
              Record shop rent, utility tokens, salaries, transport, and operational costs
            </p>
          </div>

          <button phx-click="open_new_modal" class="btn btn-warning font-bold shadow-md">
            <.icon name="hero-plus" class="w-4 h-4 mr-1" /> Log New Expense
          </button>
        </div>

        <%!-- Expense Stream Table --%>
        <div class="bg-base-100 border border-base-300 rounded-2xl overflow-hidden shadow-xs">
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full text-left">
              <thead class="bg-base-200/50 text-xs font-bold uppercase tracking-wider text-base-content/70">
                <tr>
                  <th class="py-3 px-4">Date</th>
                  <th class="py-3 px-4">Description</th>
                  <th class="py-3 px-4">Category</th>
                  <th class="py-3 px-4">Paid Via</th>
                  <th class="py-3 px-4">Receipt Ref</th>
                  <th class="py-3 px-4 text-right">Amount</th>
                </tr>
              </thead>
              <tbody id="expenses-stream" phx-update="stream">
                <tr id="empty-expenses-row" class="hidden only:table-row">
                  <td colspan="6" class="text-center py-8 text-base-content/50 text-sm">
                    No expenses logged yet.
                  </td>
                </tr>

                <tr :for={{id, expense} <- @streams.expenses} id={id} class="hover:bg-base-200/40">
                  <td class="text-xs font-semibold py-3.5 px-4 text-base-content/70">
                    {expense.date}
                  </td>
                  <td class="font-bold text-sm text-base-content py-3.5 px-4">
                    {expense.description}
                  </td>
                  <td class="py-3.5 px-4">
                    <span class="badge badge-warning badge-sm font-bold uppercase">
                      {expense.category}
                    </span>
                  </td>
                  <td class="py-3.5 px-4 text-xs font-bold uppercase">
                    {expense.payment_method}
                  </td>
                  <td class="text-xs font-mono text-base-content/60 py-3.5 px-4">
                    {expense.receipt_ref || "-"}
                  </td>
                  <td class="font-black text-sm text-right py-3.5 px-4 text-error">
                    - KES {format_money(expense.amount)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <%!-- Expense Modal Form --%>
      <%= if @show_modal do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-md p-6 rounded-3xl space-y-4">
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <h3 class="font-black text-xl">Log Expense</h3>
              <button phx-click="close_modal" class="btn btn-circle btn-ghost btn-xs">
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <.form for={@expense_form} id="expense-form" phx-submit="save_expense" class="space-y-4">
              <div>
                <label class="text-xs font-bold text-base-content/70">Expense Description</label>
                <.input
                  field={@expense_form[:description]}
                  type="text"
                  placeholder="e.g. Electricity Token or Shop Rent"
                  required
                  class="w-full"
                />
              </div>

              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="text-xs font-bold text-base-content/70">Category</label>
                  <.input
                    field={@expense_form[:category]}
                    type="select"
                    options={[
                      {"Rent", "rent"},
                      {"Utilities", "utilities"},
                      {"Salaries", "salaries"},
                      {"Transport", "transport"},
                      {"General", "general"}
                    ]}
                    required
                    class="w-full"
                  />
                </div>

                <div>
                  <label class="text-xs font-bold text-base-content/70">Payment Method</label>
                  <.input
                    field={@expense_form[:payment_method]}
                    type="select"
                    options={[{"Cash", "cash"}, {"M-Pesa", "mpesa"}, {"Bank", "bank"}]}
                    required
                    class="w-full"
                  />
                </div>
              </div>

              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="text-xs font-bold text-base-content/70">Amount (KES)</label>
                  <.input
                    field={@expense_form[:amount]}
                    type="number"
                    step="0.01"
                    placeholder="1200.00"
                    required
                    class="w-full"
                  />
                </div>

                <div>
                  <label class="text-xs font-bold text-base-content/70">Date</label>
                  <.input field={@expense_form[:date]} type="date" required class="w-full" />
                </div>
              </div>

              <div>
                <label class="text-xs font-bold text-base-content/70">Receipt / Transaction Ref (Optional)</label>
                <.input
                  field={@expense_form[:receipt_ref]}
                  type="text"
                  placeholder="e.g. MPESA-CONFIRMATION-ID"
                  class="w-full"
                />
              </div>

              <div class="flex justify-end gap-2 pt-2">
                <button type="button" phx-click="close_modal" class="btn btn-ghost rounded-xl">
                  Cancel
                </button>
                <button type="submit" class="btn btn-warning rounded-xl font-bold">
                  Save & Post Expense
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  defp format_money(nil), do: "0.00"

  defp format_money(val) do
    val
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end
end
