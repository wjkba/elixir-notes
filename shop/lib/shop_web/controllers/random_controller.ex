defmodule ShopWeb.RandomController do
  use ShopWeb, :controller

  def random(conn, _params) do
    render(conn, :index)
  end
end
