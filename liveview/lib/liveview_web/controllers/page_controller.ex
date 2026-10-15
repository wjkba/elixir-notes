defmodule LiveviewWeb.PageController do
  use LiveviewWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
