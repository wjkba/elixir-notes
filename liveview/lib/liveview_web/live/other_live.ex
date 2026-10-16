defmodule LiveviewWeb.OtherPageLive do
  use LiveviewWeb, :live_view
  import LiveviewWeb.MyCoreComponents

  def render(assigns) do
    ~H"""
    <.hero>
      <:title>OtherPageLive</:title>
      <:subtitle>You're on the first step!</:subtitle>
    </.hero>
    <.link navigate={~p"/"}>Go to home</.link>
    """
  end
end
