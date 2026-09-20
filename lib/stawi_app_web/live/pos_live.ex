defmodule StawiAppWeb.PosLive do
  use StawiAppWeb, :live_view

  alias StawiApp.Inventory
  alias StawiApp.Sales

  @impl true
  def mount(_params, _session, socket) do
    products = Inventory.list_products()
    categories = ["All" | Enum.uniq(Enum.map(products, & &1.category))]
    customers = Sales.list_customers()

    {:ok,
     socket
     |> assign(:products, products)
     |> assign(:categories, categories)
     |> assign(:selected_category, "All")
     |> assign(:search_query, "")
     # [%{product: product, quantity: int, subtotal: Decimal}]
     |> assign(:cart, [])
     |> assign(:customers, customers)
     |> assign(:selected_customer_id, "")
     |> assign(:discount_amount, "0")
     |> assign(:payment_method, "cash")
     |> assign(:cash_given, "")
     |> assign(:show_checkout_modal, false)
     |> assign(:completed_sale, nil)
     |> assign(:show_receipt_modal, false)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    products = Inventory.search_products(query)
    filtered = filter_by_category(products, socket.assigns.selected_category)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:products, filtered)}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    products = Inventory.search_products(socket.assigns.search_query)
    filtered = filter_by_category(products, category)

    {:noreply,
     socket
     |> assign(:selected_category, category)
     |> assign(:products, filtered)}
  end

  @impl true
  def handle_event("add_to_cart", %{"product_id" => product_id}, socket) do
    product = Inventory.get_product!(product_id)
    cart = socket.assigns.cart

    updated_cart =
      case Enum.find_index(cart, fn item -> item.product.id == product.id end) do
        nil ->
          cart ++ [%{product: product, quantity: 1, subtotal: product.unit_price}]

        idx ->
          List.update_at(cart, idx, fn item ->
            new_qty = item.quantity + 1
            new_subtotal = Decimal.mult(product.unit_price, Decimal.new(new_qty))
            %{item | quantity: new_qty, subtotal: new_subtotal}
          end)
      end

    {:noreply, assign(socket, :cart, updated_cart)}
  end

  @impl true
  def handle_event(
        "update_cart_quantity",
        %{"product_id" => product_id, "delta" => delta},
        socket
      ) do
    delta_int = String.to_integer(delta)
    cart = socket.assigns.cart

    updated_cart =
      case Enum.find_index(cart, fn item -> item.product.id == String.to_integer(product_id) end) do
        nil ->
          cart

        idx ->
          item = Enum.at(cart, idx)
          new_qty = item.quantity + delta_int

          if new_qty > 0 do
            new_subtotal = Decimal.mult(item.product.unit_price, Decimal.new(new_qty))
            List.replace_at(cart, idx, %{item | quantity: new_qty, subtotal: new_subtotal})
          else
            List.delete_at(cart, idx)
          end
      end

    {:noreply, assign(socket, :cart, updated_cart)}
  end

  @impl true
  def handle_event("remove_from_cart", %{"product_id" => product_id}, socket) do
    pid = String.to_integer(product_id)
    cart = Enum.reject(socket.assigns.cart, fn item -> item.product.id == pid end)
    {:noreply, assign(socket, :cart, cart)}
  end

  @impl true
  def handle_event("clear_cart", _params, socket) do
    {:noreply, assign(socket, cart: [], discount_amount: "0")}
  end

  @impl true
  def handle_event("open_checkout", _params, socket) do
    if socket.assigns.cart == [] do
      {:noreply, put_flash(socket, :error, "Cart is empty!")}
    else
      total = calculate_cart_total(socket.assigns.cart, socket.assigns.discount_amount)

      {:noreply,
       socket
       |> assign(:cash_given, Decimal.to_string(total))
       |> assign(:show_checkout_modal, true)}
    end
  end

  @impl true
  def handle_event("close_checkout", _params, socket) do
    {:noreply, assign(socket, :show_checkout_modal, false)}
  end

  @impl true
  def handle_event("set_payment_method", %{"method" => method}, socket) do
    {:noreply, assign(socket, :payment_method, method)}
  end

  @impl true
  def handle_event("set_cash_preset", %{"amount" => amount}, socket) do
    {:noreply, assign(socket, :cash_given, amount)}
  end

  @impl true
  def handle_event("update_cash_given", params, socket) do
    cash_given = params["cash_given"] || params["value"] || "0"
    {:noreply, assign(socket, :cash_given, cash_given)}
  end

  @impl true
  def handle_event("update_discount", params, socket) do
    discount = params["discount"] || params["value"] || "0"
    total = calculate_cart_total(socket.assigns.cart, discount)

    {:noreply,
     socket
     |> assign(:discount_amount, discount)
     |> assign(:cash_given, Decimal.to_string(total))}
  end

  @impl true
  def handle_event("select_customer", %{"customer_id" => customer_id}, socket) do
    {:noreply, assign(socket, :selected_customer_id, customer_id)}
  end

  @impl true
  def handle_event("complete_sale", _params, socket) do
    cart = socket.assigns.cart
    discount = parse_decimal(socket.assigns.discount_amount)

    gross_total =
      Enum.reduce(cart, Decimal.new("0.0"), fn i, acc -> Decimal.add(acc, i.subtotal) end)

    net_total = Decimal.sub(gross_total, discount)
    paid_amount = parse_decimal(socket.assigns.cash_given)

    payment_status =
      cond do
        Decimal.compare(paid_amount, net_total) in [:gt, :eq] -> "paid"
        Decimal.gt?(paid_amount, Decimal.new("0")) -> "partial"
        true -> "unpaid"
      end

    customer_id =
      case socket.assigns.selected_customer_id do
        "" -> nil
        id -> id
      end

    sale_items =
      Enum.map(cart, fn item ->
        %{
          "product_id" => item.product.id,
          "quantity" => item.quantity,
          "unit_price" => item.product.unit_price,
          "subtotal" => item.subtotal
        }
      end)

    sale_params = %{
      "customer_id" => customer_id,
      "total_amount" => net_total,
      "discount_amount" => discount,
      "paid_amount" => paid_amount,
      "payment_status" => payment_status,
      "payment_method" => socket.assigns.payment_method,
      "sale_items" => sale_items
    }

    case Sales.record_sale(sale_params) do
      {:ok, sale} ->
        # Refresh products to reflect updated inventory
        products = Inventory.list_products()

        {:noreply,
         socket
         |> assign(:products, products)
         |> assign(:cart, [])
         |> assign(:discount_amount, "0")
         |> assign(:show_checkout_modal, false)
         |> assign(:completed_sale, sale)
         |> assign(:show_receipt_modal, true)
         |> put_flash(:info, "Sale recorded successfully!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to record sale. Please check inputs.")}
    end
  end

  @impl true
  def handle_event("close_receipt", _params, socket) do
    {:noreply, assign(socket, show_receipt_modal: false, completed_sale: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        <%!-- Left Section: Search & Touch Product Catalog --%>
        <div class="lg:col-span-7 xl:col-span-8 space-y-4">
          <%!-- Search & Header --%>
          <div class="bg-base-100 p-4 rounded-2xl border border-base-300 shadow-xs space-y-3">
            <div class="flex items-center justify-between">
              <h1 class="font-black text-xl tracking-tight text-base-content flex items-center gap-2">
                <.icon name="hero-shopping-bag" class="w-6 h-6 text-primary" /> Point of Sale
              </h1>
              <span class="text-xs font-bold text-base-content/60">
                {length(@products)} Products
              </span>
            </div>

            <form phx-change="search" phx-submit="search" class="relative">
              <.icon
                name="hero-magnifying-glass"
                class="w-5 h-5 absolute left-3 top-3 text-base-content/40"
              />
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search products by name, SKU or barcode..."
                class="input input-bordered w-full pl-10 rounded-xl bg-base-200/50 focus:bg-base-100"
                phx-debounce="300"
              />
            </form>

            <%!-- Category Filter Pills --%>
            <div class="flex items-center gap-2 overflow-x-auto pb-1 no-scrollbar">
              <%= for cat <- @categories do %>
                <button
                  type="button"
                  phx-click="filter_category"
                  phx-value-category={cat}
                  class={[
                    "btn btn-xs rounded-full font-semibold transition-all whitespace-nowrap",
                    if(@selected_category == cat,
                      do: "btn-primary shadow-xs",
                      else: "btn-ghost bg-base-200"
                    )
                  ]}
                >
                  {cat}
                </button>
              <% end %>
            </div>
          </div>

          <%!-- Products Grid --%>
          <div class="grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-4 gap-3">
            <%= for product <- @products do %>
              <div
                phx-click="add_to_cart"
                phx-value-product_id={product.id}
                class="card bg-base-100 border border-base-300 hover:border-primary p-3 rounded-2xl shadow-xs cursor-pointer active:scale-95 transition-all group relative overflow-hidden"
              >
                <%= if product.stock_quantity <= product.min_stock_level do %>
                  <div class="absolute top-2 right-2 badge badge-warning badge-xs font-bold">
                    Low Stock
                  </div>
                <% end %>

                <div class="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-black text-sm mb-2 group-hover:bg-primary group-hover:text-primary-content transition-colors">
                  {String.slice(product.name, 0, 2)}
                </div>

                <div class="font-bold text-sm text-base-content line-clamp-1">
                  {product.name}
                </div>
                <div class="text-xs text-base-content/60">
                  {product.unit} &bull; Stock: {product.stock_quantity}
                </div>

                <div class="mt-2 flex items-center justify-between">
                  <span class="font-black text-sm text-primary">
                    KES {format_money(product.unit_price)}
                  </span>
                  <div class="btn btn-circle btn-primary btn-xs opacity-80 group-hover:opacity-100">
                    <.icon name="hero-plus" class="w-3.5 h-3.5" />
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Right Section: Cart Panel --%>
        <div class="lg:col-span-5 xl:col-span-4 bg-base-100 border border-base-300 rounded-2xl p-4 sm:p-5 shadow-xs space-y-4 lg:sticky lg:top-20">
          <div class="flex items-center justify-between border-b border-base-200 pb-3">
            <h2 class="font-bold text-lg flex items-center gap-2">
              <.icon name="hero-shopping-cart" class="w-5 h-5 text-primary" /> Current Order
            </h2>

            <%= if @cart != [] do %>
              <button phx-click="clear_cart" class="btn btn-ghost btn-xs text-error">
                Clear Cart
              </button>
            <% end %>
          </div>

          <%!-- Cart Items List --%>
          <div class="space-y-3 max-h-80 overflow-y-auto pr-1">
            <%= if @cart == [] do %>
              <div class="text-center py-10 text-base-content/50 text-sm space-y-2">
                <.icon name="hero-shopping-bag" class="w-10 h-10 mx-auto opacity-30" />
                <p>Tap products on the left to add to order</p>
              </div>
            <% else %>
              <%= for item <- @cart do %>
                <div class="flex items-center justify-between p-2.5 rounded-xl bg-base-200/50 border border-base-200">
                  <div class="flex-1 min-w-0 pr-2">
                    <div class="font-bold text-sm truncate">{item.product.name}</div>
                    <div class="text-xs text-base-content/60">
                      KES {format_money(item.product.unit_price)} / {item.product.unit}
                    </div>
                  </div>

                  <div class="flex items-center gap-2">
                    <div class="flex items-center bg-base-100 border border-base-300 rounded-lg">
                      <button
                        phx-click="update_cart_quantity"
                        phx-value-product_id={item.product.id}
                        phx-value-delta="-1"
                        class="px-2 py-1 hover:bg-base-200 rounded-l-lg text-sm font-bold"
                      >
                        -
                      </button>
                      <span class="px-2.5 text-xs font-black">{item.quantity}</span>
                      <button
                        phx-click="update_cart_quantity"
                        phx-value-product_id={item.product.id}
                        phx-value-delta="1"
                        class="px-2 py-1 hover:bg-base-200 rounded-r-lg text-sm font-bold"
                      >
                        +
                      </button>
                    </div>

                    <div class="font-black text-sm text-base-content w-16 text-right">
                      KES {format_money(item.subtotal)}
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <%!-- Order Totals Summary --%>
          <%= if @cart != [] do %>
            <div class="border-t border-base-200 pt-3 space-y-2">
              <div class="flex items-center justify-between text-xs text-base-content/70">
                <span>Subtotal ({calculate_total_items(@cart)} items)</span>
                <span class="font-bold text-sm text-base-content">
                  KES {format_money(calculate_subtotal(@cart))}
                </span>
              </div>

              <div class="flex items-center justify-between gap-2">
                <span class="text-xs text-base-content/70">Discount (KES)</span>
                <input
                  type="number"
                  value={@discount_amount}
                  phx-change="update_discount"
                  name="discount"
                  class="input input-xs input-bordered w-24 text-right font-semibold rounded-md"
                />
              </div>

              <div class="flex items-center justify-between text-lg font-black border-t border-base-200 pt-2 text-base-content">
                <span>Total Amount</span>
                <span class="text-primary">
                  KES {format_money(calculate_cart_total(@cart, @discount_amount))}
                </span>
              </div>

              <button
                phx-click="open_checkout"
                class="btn btn-primary w-full btn-lg rounded-xl font-extrabold shadow-md mt-2"
              >
                Checkout Now &rarr;
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Checkout Payment Drawer Modal --%>
      <%= if @show_checkout_modal do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-md p-6 rounded-3xl space-y-4">
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <h3 class="font-black text-xl flex items-center gap-2">
                <.icon name="hero-credit-card" class="w-6 h-6 text-primary" /> Complete Checkout
              </h3>
              <button phx-click="close_checkout" class="btn btn-circle btn-ghost btn-xs">
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <div class="bg-primary/10 p-3.5 rounded-2xl space-y-2">
              <div class="flex items-center justify-between text-xs text-base-content/70">
                <span>Subtotal ({calculate_total_items(@cart)} items)</span>
                <span class="font-bold text-sm text-base-content">
                  KES {format_money(calculate_subtotal(@cart))}
                </span>
              </div>

              <div class="flex items-center justify-between gap-2">
                <span class="text-xs font-bold text-base-content/70">Discount (KES)</span>
                <input
                  type="number"
                  value={@discount_amount}
                  phx-change="update_discount"
                  name="discount"
                  class="input input-xs input-bordered w-28 text-right font-bold rounded-lg"
                />
              </div>

              <div class="flex items-center justify-between border-t border-primary/20 pt-2">
                <span class="text-xs font-extrabold uppercase tracking-wider text-primary">Net Total Payable</span>
                <span class="text-2xl font-black text-primary">
                  KES {format_money(calculate_cart_total(@cart, @discount_amount))}
                </span>
              </div>
            </div>

            <%!-- Payment Method Toggle --%>
            <div class="space-y-1.5">
              <label class="text-xs font-bold text-base-content/70">Payment Method</label>
              <div class="grid grid-cols-4 gap-2">
                <%= for {m, label, icon} <- [{"cash", "Cash", "hero-banknotes"}, {"mpesa", "M-Pesa", "hero-device-phone-mobile"}, {"bank", "Bank", "hero-building-library"}, {"credit", "Credit", "hero-clock"}] do %>
                  <button
                    type="button"
                    phx-click="set_payment_method"
                    phx-value-method={m}
                    class={[
                      "btn btn-sm rounded-xl font-bold flex flex-col items-center py-2 h-auto text-xs",
                      if(@payment_method == m,
                        do: "btn-primary shadow-xs",
                        else: "btn-ghost bg-base-200"
                      )
                    ]}
                  >
                    <.icon name={icon} class="w-4 h-4 mb-0.5" />
                    {label}
                  </button>
                <% end %>
              </div>
            </div>

            <%!-- Optional Customer Selector --%>
            <div class="space-y-1.5">
              <label class="text-xs font-bold text-base-content/70">
                Customer (Optional for Walk-ins)
              </label>
              <select
                phx-change="select_customer"
                name="customer_id"
                class="select select-bordered w-full rounded-xl text-sm font-medium"
              >
                <option value="">Walk-in Customer (Anonymous)</option>
                <%= for cust <- @customers do %>
                  <option value={cust.id} selected={to_string(cust.id) == @selected_customer_id}>
                    {cust.name} ({cust.phone || "No phone"})
                  </option>
                <% end %>
              </select>
            </div>

            <%!-- Cash Given & Quick Presets --%>
            <div class="space-y-1.5">
              <div class="flex items-center justify-between">
                <label class="text-xs font-bold text-base-content/70">Amount Received (KES)</label>
                <span class="text-xs text-base-content/60 font-medium">
                  Change: KES {format_money(
                    calculate_change(calculate_cart_total(@cart, @discount_amount), @cash_given)
                  )}
                </span>
              </div>
              <input
                type="number"
                value={@cash_given}
                phx-change="update_cash_given"
                name="cash_given"
                class="input input-bordered w-full text-lg font-black text-right rounded-xl"
              />

              <%!-- Quick Cash Preset Buttons --%>
              <div class="flex items-center gap-1.5 overflow-x-auto pt-1">
                <% total_str = Decimal.to_string(calculate_cart_total(@cart, @discount_amount)) %>
                <button
                  type="button"
                  phx-click="set_cash_preset"
                  phx-value-amount={total_str}
                  class="btn btn-xs btn-ghost bg-base-200 rounded-lg font-bold"
                >
                  Exact
                </button>
                <%= for preset <- ["100", "200", "500", "1000", "2000", "5000"] do %>
                  <button
                    type="button"
                    phx-click="set_cash_preset"
                    phx-value-amount={preset}
                    class="btn btn-xs btn-ghost bg-base-200 rounded-lg font-semibold"
                  >
                    KES {preset}
                  </button>
                <% end %>
              </div>
            </div>

            <button
              phx-click="complete_sale"
              class="btn btn-primary w-full btn-lg rounded-2xl font-black shadow-lg"
            >
              Confirm & Complete Sale &rarr;
            </button>
          </div>
        </div>
      <% end %>

      <%!-- Digital Receipt Viewer Modal --%>
      <%= if @show_receipt_modal && @completed_sale do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-sm p-6 rounded-3xl space-y-4 text-center">
            <div class="w-12 h-12 bg-success/10 text-success rounded-full flex items-center justify-center mx-auto">
              <.icon name="hero-check-circle" class="w-8 h-8" />
            </div>

            <div>
              <h3 class="font-black text-xl">Sale Complete!</h3>
              <p class="text-xs text-base-content/60">
                Receipt #{@completed_sale.sale_number}
              </p>
            </div>

            <%!-- Receipt Ticket Card --%>
            <div class="bg-base-200/60 p-4 rounded-2xl border border-dashed border-base-300 text-left text-xs font-mono space-y-2">
              <div class="text-center border-b border-base-300 pb-2">
                <div class="font-bold text-sm">STAWI SME STORE</div>
                <div>Walk-in Receipt</div>
                <div>{format_time(@completed_sale.sale_date)}</div>
              </div>

              <div class="space-y-1 py-1">
                <%= for item <- @completed_sale.sale_items do %>
                  <div class="flex justify-between">
                    <span>{item.product.name} x{item.quantity}</span>
                    <span>{format_money(item.subtotal)}</span>
                  </div>
                <% end %>
              </div>

              <div class="border-t border-base-300 pt-2 space-y-1 font-sans">
                <div class="flex justify-between font-bold text-sm">
                  <span>Total Paid ({String.upcase(@completed_sale.payment_method)})</span>
                  <span>KES {format_money(@completed_sale.paid_amount)}</span>
                </div>
              </div>
            </div>

            <div class="flex gap-2">
              <button onclick="window.print()" class="btn btn-outline flex-1 rounded-xl">
                <.icon name="hero-printer" class="w-4 h-4 mr-1" /> Print
              </button>
              <button phx-click="close_receipt" class="btn btn-primary flex-1 rounded-xl font-bold">
                Done & New Sale
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  defp filter_by_category(products, "All"), do: products

  defp filter_by_category(products, category) do
    Enum.filter(products, &(&1.category == category))
  end

  defp calculate_total_items(cart) do
    Enum.reduce(cart, 0, fn item, acc -> acc + item.quantity end)
  end

  defp calculate_subtotal(cart) do
    Enum.reduce(cart, Decimal.new("0.0"), fn item, acc -> Decimal.add(acc, item.subtotal) end)
  end

  defp calculate_cart_total(cart, discount_str) do
    subtotal = calculate_subtotal(cart)
    discount = parse_decimal(discount_str)
    res = Decimal.sub(subtotal, discount)
    if Decimal.lt?(res, 0), do: Decimal.new("0.0"), else: res
  end

  defp calculate_change(total_decimal, cash_given_str) do
    given = parse_decimal(cash_given_str)
    change = Decimal.sub(given, total_decimal)
    if Decimal.lt?(change, 0), do: Decimal.new("0.0"), else: change
  end

  defp parse_decimal(nil), do: Decimal.new("0.0")
  defp parse_decimal(%Decimal{} = d), do: d
  defp parse_decimal(num) when is_number(num), do: Decimal.new(to_string(num))

  defp parse_decimal(str) when is_binary(str) do
    case Decimal.parse(String.trim(str)) do
      {d, _} -> d
      :error -> Decimal.new("0.0")
    end
  end

  defp parse_decimal(_), do: Decimal.new("0.0")

  defp format_money(nil), do: "0.00"

  defp format_money(val) do
    val
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end

  defp format_time(nil), do: ""

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %I:%M %p")
  end

  defp format_time(_), do: ""
end
