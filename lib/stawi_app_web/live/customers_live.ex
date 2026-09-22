defmodule StawiAppWeb.CustomersLive do
  use StawiAppWeb, :live_view

  alias StawiApp.Sales
  alias StawiApp.Sales.Customer

  @impl true
  def mount(_params, _session, socket) do
    customers = Sales.list_customers()

    {:ok,
     socket
     |> assign(:customers_list, customers)
     |> assign(:show_modal, false)
     |> assign(:customer_form, to_form(Sales.change_customer(%Customer{})))
     |> stream(:customers, customers)}
  end

  @impl true
  def handle_event("open_new_modal", _params, socket) do
    changeset = Sales.change_customer(%Customer{})
    {:noreply, assign(socket, customer_form: to_form(changeset), show_modal: true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  @impl true
  def handle_event("save_customer", %{"customer" => params}, socket) do
    case Sales.create_customer(params) do
      {:ok, _customer} ->
        updated = Sales.list_customers()

        {:noreply,
         socket
         |> assign(:customers_list, updated)
         |> stream(:customers, updated, reset: true)
         |> assign(:show_modal, false)
         |> put_flash(:info, "Customer profile created!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :customer_form, to_form(changeset))}
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
              <.icon name="hero-users" class="w-6 h-6 text-secondary" />
              Customer Directory & Debt Ledger
            </h1>
            <p class="text-sm text-base-content/70 mt-0.5">
              Track store credit, phone contacts, and customer debt balances (Optional for walk-in merchants)
            </p>
          </div>

          <button phx-click="open_new_modal" class="btn btn-secondary font-bold shadow-md">
            <.icon name="hero-plus" class="w-4 h-4 mr-1" /> Add Customer Profile
          </button>
        </div>

        <%!-- Customer Stream Table --%>
        <div class="bg-base-100 border border-base-300 rounded-2xl overflow-hidden shadow-xs">
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full text-left">
              <thead class="bg-base-200/50 text-xs font-bold uppercase tracking-wider text-base-content/70">
                <tr>
                  <th class="py-3 px-4">Customer Name</th>
                  <th class="py-3 px-4">Phone Number</th>
                  <th class="py-3 px-4">Email</th>
                  <th class="py-3 px-4 text-right">Store Credit / Debt Balance</th>
                </tr>
              </thead>
              <tbody id="customers-stream" phx-update="stream">
                <tr id="empty-customers-row" class="hidden only:table-row">
                  <td colspan="4" class="text-center py-8 text-base-content/50 text-sm">
                    No customer profiles created yet. POS sales default to anonymous walk-in customers.
                  </td>
                </tr>

                <tr :for={{id, customer} <- @streams.customers} id={id} class="hover:bg-base-200/40">
                  <td class="font-bold text-sm text-base-content py-3.5 px-4">
                    {customer.name}
                  </td>
                  <td class="text-xs font-mono text-base-content/70 py-3.5 px-4">
                    {customer.phone || "No phone"}
                  </td>
                  <td class="text-xs text-base-content/70 py-3.5 px-4">
                    {customer.email || "No email"}
                  </td>
                  <td class="font-black text-sm text-right py-3.5 px-4">
                    <span class={[
                      if(Decimal.gt?(customer.balance, 0),
                        do: "text-warning font-black",
                        else: "text-base-content/70"
                      )
                    ]}>
                      KES {format_money(customer.balance)}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <%!-- Modal Form --%>
      <%= if @show_modal do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-md p-6 rounded-3xl space-y-4">
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <h3 class="font-black text-xl">New Customer Profile</h3>
              <button phx-click="close_modal" class="btn btn-circle btn-ghost btn-xs">
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <.form
              for={@customer_form}
              id="customer-form"
              phx-submit="save_customer"
              class="space-y-4"
            >
              <div>
                <label class="text-xs font-bold text-base-content/70">Customer / Business Name</label>
                <.input
                  field={@customer_form[:name]}
                  type="text"
                  placeholder="e.g. Jane Wanjiku"
                  required
                  class="w-full"
                />
              </div>

              <div>
                <label class="text-xs font-bold text-base-content/70">Phone Number (Optional)</label>
                <.input
                  field={@customer_form[:phone]}
                  type="text"
                  placeholder="e.g. +254712345678"
                  class="w-full"
                />
              </div>

              <div>
                <label class="text-xs font-bold text-base-content/70">Email Address (Optional)</label>
                <.input
                  field={@customer_form[:email]}
                  type="email"
                  placeholder="e.g. jane@example.com"
                  class="w-full"
                />
              </div>

              <div class="flex justify-end gap-2 pt-2">
                <button type="button" phx-click="close_modal" class="btn btn-ghost rounded-xl">
                  Cancel
                </button>
                <button type="submit" class="btn btn-secondary rounded-xl font-bold">
                  Save Customer
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
