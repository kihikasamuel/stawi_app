defmodule StawiApp.Inventory do
  @moduledoc """
  The Inventory context for managing products, categories, and stock quantities.
  """
  import Ecto.Query, warn: false
  alias StawiApp.Repo
  alias StawiApp.Inventory.Product

  def list_products do
    Product
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  def search_products(query) when is_binary(query) and query != "" do
    search_term = "%#{query}%"

    Product
    |> where(
      [p],
      ilike(p.name, ^search_term) or ilike(p.sku, ^search_term) or ilike(p.category, ^search_term)
    )
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  def search_products(_), do: list_products()

  def list_low_stock_products do
    Product
    |> where([p], p.stock_quantity <= p.min_stock_level)
    |> order_by([p], asc: p.stock_quantity)
    |> Repo.all()
  end

  def get_product!(id), do: Repo.get!(Product, id)

  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end

  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  def update_stock_quantity(product_id, delta_quantity) do
    product = get_product!(product_id)
    new_quantity = max(0, product.stock_quantity + delta_quantity)
    update_product(product, %{stock_quantity: new_quantity})
  end
end
