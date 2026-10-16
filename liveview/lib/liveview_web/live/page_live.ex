defmodule LiveviewWeb.PageLive do
  use LiveviewWeb, :live_view

  @initial_state %{
    "name" => "",
    "description" => ""
  }

  def mount(_params, _session, socket) do
    form = to_form(@initial_state, as: :product)
    {:ok, assign(socket, form: form)}
  end

  def handle_event("create_product", %{"product" => product_params}, socket) do
    IO.inspect({"Form submitted!!", product_params})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        phx-submit="create_product"
        class="flex flex-col max-w-96 mx-auto p-24"
      >
        <h1 class="text-blue-500">Creating a product</h1>
        <.my_input field={@form[:name]} placeholder="Name" />
        <.my_input field={@form[:description]} placeholder="Description" />

        <button type="submit">Send</button>
      </.form>
    </div>
    """
  end
end
