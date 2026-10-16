defmodule LiveviewWeb.BlogLive do
  use LiveviewWeb, :live_view

  def mount(%{"slug" => slug}, _session, socket) do
    socket = assign(socket, :slug, slug)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h1>Reading about {@slug}</h1>
    """
  end
end
