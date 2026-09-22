defmodule StawiAppWeb.ProductsLive do
  use StawiAppWeb, :live_view

  alias StawiApp.Inventory
  alias StawiApp.Inventory.Product

  @impl true
  def mount(_params, _session, socket) do
    products = Inventory.list_products()

    {:ok,
     socket
     |> assign(:all_products, products)
     |> assign(:selected_filter, "all")
     |> assign(:show_product_modal, false)
     |> assign(:product_form, to_form(Inventory.change_product(%Product{})))
     |> assign(:editing_product, nil)
     |> stream(:products, products)}
  end

  @impl true
  def handle_event("filter_products", %{"filter" => filter}, socket) do
    filtered =
      case filter do
        "all" ->
          socket.assigns.all_products

        "low_stock" ->
          Enum.filter(socket.assigns.all_products, &(&1.stock_quantity <= &1.min_stock_level))

        _ ->
          socket.assigns.all_products
      end

    {:noreply,
     socket
     |> assign(:selected_filter, filter)
     |> stream(:products, filtered, reset: true)}
  end

  @impl true
  def handle_event("open_new_modal", _params, socket) do
    changeset = Inventory.change_product(%Product{})

    {:noreply,
     socket
     |> assign(:editing_product, nil)
     |> assign(:product_form, to_form(changeset))
     |> assign(:show_product_modal, true)}
  end

  @impl true
  def handle_event("edit_product", %{"id" => id}, socket) do
    product = Inventory.get_product!(id)
    changeset = Inventory.change_product(product)

    {:noreply,
     socket
     |> assign(:editing_product, product)
     |> assign(:product_form, to_form(changeset))
     |> assign(:show_product_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_product_modal: false, editing_product: nil)}
  end

  @impl true
  def handle_event("save_product", %{"product" => params}, socket) do
    result =
      case socket.assigns.editing_product do
        nil -> Inventory.create_product(params)
        product -> Inventory.update_product(product, params)
      end

    case result do
      {:ok, _product} ->
        updated_products = Inventory.list_products()

        {:noreply,
         socket
         |> assign(:all_products, updated_products)
         |> stream(:products, updated_products, reset: true)
         |> assign(:show_product_modal, false)
         |> put_flash(:info, "Product saved successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :product_form, to_form(changeset))}
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
              <.icon name="hero-cube" class="w-6 h-6 text-info" /> Products & Inventory Catalog
            </h1>
            <p class="text-sm text-base-content/70 mt-0.5">
              Manage stock quantities, unit prices, cost of goods, and low-stock reorder thresholds
            </p>
          </div>

          <button phx-click="open_new_modal" class="btn btn-primary font-bold shadow-md">
            <.icon name="hero-plus" class="w-4 h-4 mr-1" /> Add New Product
          </button>
        </div>

        <%!-- Filter Tabs --%>
        <div class="flex items-center gap-2 bg-base-100 p-2 rounded-xl border border-base-300 w-fit">
          <button
            type="button"
            phx-click="filter_products"
            phx-value-filter="all"
            class={[
              "btn btn-xs rounded-lg font-bold transition-all",
              if(@selected_filter == "all", do: "btn-primary shadow-xs", else: "btn-ghost")
            ]}
          >
            All Products ({length(@all_products)})
          </button>

          <button
            type="button"
            phx-click="filter_products"
            phx-value-filter="low_stock"
            class={[
              "btn btn-xs rounded-lg font-bold transition-all",
              if(@selected_filter == "low_stock", do: "btn-warning shadow-xs", else: "btn-ghost")
            ]}
          >
            <.icon name="hero-exclamation-triangle" class="w-3.5 h-3.5 mr-1" />
            Low Stock Alerts ({length(
              Enum.filter(@all_products, &(&1.stock_quantity <= &1.min_stock_level))
            )})
          </button>
        </div>

        <%!-- Product Table --%>
        <div class="bg-base-100 border border-base-300 rounded-2xl overflow-hidden shadow-xs">
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full text-left">
              <thead class="bg-base-200/50 text-xs font-bold uppercase tracking-wider text-base-content/70">
                <tr>
                  <th class="py-3 px-4">Item & SKU</th>
                  <th class="py-3 px-4">Category</th>
                  <th class="py-3 px-4 text-right">Selling Price</th>
                  <th class="py-3 px-4 text-right">Cost Price</th>
                  <th class="py-3 px-4 text-center">Stock Level</th>
                  <th class="py-3 px-4 text-center">Action</th>
                </tr>
              </thead>
              <tbody id="products-stream" phx-update="stream">
                <tr id="empty-products-row" class="hidden only:table-row">
                  <td colspan="6" class="text-center py-8 text-base-content/50 text-sm">
                    No products found.
                  </td>
                </tr>

                <tr :for={{id, product} <- @streams.products} id={id} class="hover:bg-base-200/40">
                  <td class="py-3.5 px-4">
                    <div class="font-bold text-sm text-base-content">{product.name}</div>
                    <div class="text-xs text-base-content/60 font-mono">
                      {product.sku || "No SKU"} &bull; Unit: {product.unit}
                    </div>
                  </td>
                  <td class="py-3.5 px-4 text-sm font-medium">
                    <span class="badge badge-ghost badge-sm font-semibold">{product.category}</span>
                  </td>
                  <td class="font-black text-sm text-right py-3.5 px-4 text-primary">
                    KES {format_money(product.unit_price)}
                  </td>
                  <td class="font-medium text-xs text-right py-3.5 px-4 text-base-content/70">
                    KES {format_money(product.cost_price)}
                  </td>
                  <td class="text-center py-3.5 px-4">
                    <span class={[
                      "badge font-bold",
                      if(product.stock_quantity <= product.min_stock_level,
                        do: "badge-warning",
                        else: "badge-success"
                      )
                    ]}>
                      {product.stock_quantity} {product.unit}
                    </span>
                  </td>
                  <td class="text-center py-3.5 px-4">
                    <button
                      phx-click="edit_product"
                      phx-value-id={product.id}
                      class="btn btn-ghost btn-xs text-primary font-bold"
                    >
                      <.icon name="hero-pencil" class="w-4 h-4 mr-1" /> Edit
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <%!-- Product Form Modal --%>
      <%= if @show_product_modal do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-lg p-6 rounded-3xl space-y-4">
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <h3 class="font-black text-xl">
                {if @editing_product, do: "Edit Product", else: "Add New Product"}
              </h3>
              <button phx-click="close_modal" class="btn btn-circle btn-ghost btn-xs">
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <.form for={@product_form} id="product-form" phx-submit="save_product" class="space-y-4">
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div class="sm:col-span-2">
                  <label class="text-xs font-bold text-base-content/70">Product Name</label>
                  <.input
                    field={@product_form[:name]}
                    type="text"
                    placeholder="e.g. Maize Flour 2kg"
                    required
                    class="w-full"
                  />
                </div>

                <div>
                  <label class="text-xs font-bold text-base-content/70">SKU / Barcode</label>
                  <.input
                    field={@product_form[:sku]}
                    type="text"
                    placeholder="e.g. FLR-001"
                    class="w-full"
                  />
                </div>

                <div>
                  <label class="text-xs font-bold text-base-content/70">Category</label>
                  <.input
                    field={@product_form[:category]}
                    type="text"
                    placeholder="e.g. Groceries"
                    class="w-full"
                  />
                </div>

                <div>
                  <label class="text-xs font-bold text-base-content/70">Selling Price (KES)</label>
                  <.input
                    field={@product_form[:unit_price]}
                    type="number"
                    step="0.01"
                    placeholder="220.00"
                    required
                    class="w-full"
                  />
                </div>

                <div>
                  <label class="text-xs font-bold text-base-content/70">Cost Price (KES)</label>
                  <.input
                    field={@product_form[:cost_price]}
                    type="number"
                    step="0.01"
                    placeholder="175.00"
                    required
                    class="w-full"
                  />
                </div>

                <div>
                  <label class="text-xs font-bold text-base-content/70">Current Stock Quantity</label>
                  <.input
                    field={@product_form[:stock_quantity]}
                    type="number"
                    placeholder="50"
                    required
                    class="w-full"
                  />
                </div>

                <div>
                  <label class="text-xs font-bold text-base-content/70">Min Stock Reorder Level</label>
                  <.input
                    field={@product_form[:min_stock_level]}
                    type="number"
                    placeholder="10"
                    required
                    class="w-full"
                  />
                </div>
              </div>

              <div class="flex justify-end gap-2 pt-2">
                <button type="button" phx-click="close_modal" class="btn btn-ghost rounded-xl">
                  Cancel
                </button>
                <button type="submit" class="btn btn-primary rounded-xl font-bold">
                  Save Product
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
