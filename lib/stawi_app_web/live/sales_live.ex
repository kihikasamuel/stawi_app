defmodule StawiAppWeb.SalesLive do
  use StawiAppWeb, :live_view

  alias StawiApp.Sales

  @impl true
  def mount(_params, _session, socket) do
    all_sales = Sales.list_sales()

    {:ok,
     socket
     |> assign(:all_sales, all_sales)
     |> assign(:selected_filter, "all")
     |> assign(:selected_sale, nil)
     |> assign(:show_receipt_modal, false)
     |> stream(:sales, all_sales)}
  end

  @impl true
  def handle_event("filter_sales", %{"filter" => filter}, socket) do
    filtered =
      case filter do
        "all" ->
          socket.assigns.all_sales

        "cash" ->
          Enum.filter(socket.assigns.all_sales, &(&1.payment_method == "cash"))

        "mpesa" ->
          Enum.filter(socket.assigns.all_sales, &(&1.payment_method == "mpesa"))

        "credit" ->
          Enum.filter(
            socket.assigns.all_sales,
            &(&1.payment_method == "credit" or &1.payment_status in ["partial", "unpaid"])
          )

        _ ->
          socket.assigns.all_sales
      end

    {:noreply,
     socket
     |> assign(:selected_filter, filter)
     |> stream(:sales, filtered, reset: true)}
  end

  @impl true
  def handle_event("view_sale", %{"sale_id" => sale_id}, socket) do
    sale = Sales.get_sale!(sale_id)
    {:noreply, assign(socket, selected_sale: sale, show_receipt_modal: true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_receipt_modal: false, selected_sale: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-base-100 p-5 rounded-2xl border border-base-300 shadow-xs">
          <div>
            <h1 class="text-2xl font-black tracking-tight text-base-content flex items-center gap-2">
              <.icon name="hero-receipt-percent" class="w-6 h-6 text-accent" /> Sales History Log
            </h1>
            <p class="text-sm text-base-content/70 mt-0.5">
              Review completed walk-in transactions, receipts, and payment breakdowns
            </p>
          </div>

          <.link navigate={~p"/pos"} class="btn btn-primary font-bold shadow-md">
            <.icon name="hero-plus" class="w-4 h-4 mr-1" /> New Walk-In Sale
          </.link>
        </div>

        <%!-- Filter Tabs --%>
        <div class="flex items-center gap-2 bg-base-100 p-2 rounded-xl border border-base-300 w-fit">
          <%= for {f, label} <- [{"all", "All Sales"}, {"cash", "Cash"}, {"mpesa", "M-Pesa"}, {"credit", "Store Credit / Debt"}] do %>
            <button
              type="button"
              phx-click="filter_sales"
              phx-value-filter={f}
              class={[
                "btn btn-xs rounded-lg font-bold transition-all",
                if(@selected_filter == f, do: "btn-primary shadow-xs", else: "btn-ghost")
              ]}
            >
              {label}
            </button>
          <% end %>
        </div>

        <%!-- Sales Stream Table --%>
        <div class="bg-base-100 border border-base-300 rounded-2xl overflow-hidden shadow-xs">
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full text-left">
              <thead class="bg-base-200/50 text-xs font-bold uppercase tracking-wider text-base-content/70">
                <tr>
                  <th class="py-3 px-4">Receipt #</th>
                  <th class="py-3 px-4">Date & Time</th>
                  <th class="py-3 px-4">Customer</th>
                  <th class="py-3 px-4">Method</th>
                  <th class="py-3 px-4">Status</th>
                  <th class="py-3 px-4 text-right">Amount</th>
                  <th class="py-3 px-4 text-center">Action</th>
                </tr>
              </thead>
              <tbody id="sales-stream" phx-update="stream">
                <tr id="empty-sales-row" class="hidden only:table-row">
                  <td colspan="7" class="text-center py-8 text-base-content/50 text-sm">
                    No sales matching selected filter.
                  </td>
                </tr>

                <tr :for={{id, sale} <- @streams.sales} id={id} class="hover:bg-base-200/40">
                  <td class="font-bold text-sm text-primary py-3.5 px-4">
                    {sale.sale_number}
                  </td>
                  <td class="text-xs text-base-content/70 py-3.5 px-4">
                    {format_datetime(sale.sale_date)}
                  </td>
                  <td class="text-sm font-medium py-3.5 px-4">
                    {if sale.customer, do: sale.customer.name, else: "Walk-in Customer"}
                  </td>
                  <td class="py-3.5 px-4">
                    <span class="badge badge-sm font-bold uppercase">
                      {sale.payment_method}
                    </span>
                  </td>
                  <td class="py-3.5 px-4">
                    <span class={[
                      "badge badge-xs font-semibold uppercase",
                      if(sale.payment_status == "paid", do: "badge-success"),
                      if(sale.payment_status == "partial", do: "badge-warning"),
                      if(sale.payment_status == "unpaid", do: "badge-error")
                    ]}>
                      {sale.payment_status}
                    </span>
                  </td>
                  <td class="font-black text-sm text-right py-3.5 px-4">
                    KES {format_money(sale.total_amount)}
                  </td>
                  <td class="text-center py-3.5 px-4">
                    <button
                      phx-click="view_sale"
                      phx-value-sale_id={sale.id}
                      class="btn btn-ghost btn-xs text-primary font-bold"
                    >
                      <.icon name="hero-eye" class="w-4 h-4 mr-1" /> View
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <%!-- Receipt Modal --%>
      <%= if @show_receipt_modal && @selected_sale do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-md p-6 rounded-3xl space-y-4">
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <h3 class="font-black text-lg">Sale Receipt #{@selected_sale.sale_number}</h3>
              <button phx-click="close_modal" class="btn btn-circle btn-ghost btn-xs">
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <div class="bg-base-200/60 p-4 rounded-2xl border border-dashed border-base-300 text-xs font-mono space-y-2">
              <div class="text-center border-b border-base-300 pb-2 font-sans">
                <div class="font-bold text-sm">STAWI SME STORE</div>
                <div>Walk-in Receipt</div>
                <div>{format_datetime(@selected_sale.sale_date)}</div>
              </div>

              <div class="space-y-1.5 py-1">
                <%= for item <- @selected_sale.sale_items do %>
                  <div class="flex justify-between">
                    <span>{item.product.name} x{item.quantity}</span>
                    <span>KES {format_money(item.subtotal)}</span>
                  </div>
                <% end %>
              </div>

              <div class="border-t border-base-300 pt-2 space-y-1 font-sans">
                <div class="flex justify-between">
                  <span>Subtotal</span>
                  <span>KES {format_money(
                    Decimal.add(@selected_sale.total_amount, @selected_sale.discount_amount)
                  )}</span>
                </div>
                <%= if Decimal.gt?(@selected_sale.discount_amount, Decimal.new("0")) do %>
                  <div class="flex justify-between text-success">
                    <span>Discount</span>
                    <span>- KES {format_money(@selected_sale.discount_amount)}</span>
                  </div>
                <% end %>
                <div class="flex justify-between font-black text-sm border-t border-base-300 pt-1">
                  <span>Total Amount ({String.upcase(@selected_sale.payment_method)})</span>
                  <span>KES {format_money(@selected_sale.total_amount)}</span>
                </div>
              </div>
            </div>

            <div class="flex gap-2">
              <button onclick="window.print()" class="btn btn-outline flex-1 rounded-xl">
                <.icon name="hero-printer" class="w-4 h-4 mr-1" /> Print Receipt
              </button>
              <button phx-click="close_modal" class="btn btn-primary flex-1 rounded-xl font-bold">
                Close
              </button>
            </div>
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

  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %I:%M %p")
  end

  defp format_datetime(_), do: ""
end
