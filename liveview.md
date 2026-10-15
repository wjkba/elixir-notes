Adopt LiveView by Lubien

# First Live View

`lib/myapp_web/router.ex`
```elixir
scope "/", MyappWeb do
  pipe_through :browser

  get "/", PageController, :home
end
```

# Anatomy of a LiveView
- Mix is the Elixir project compilation tool.
- 'mix setup' is useful to get started on projects you just cloned.
- All LiveViews have a 'render/1' function and always receive an argument called 'assigns'.
- 'use MyappWeb', :live_view adds things at compile time to make your LiveView work properly.


# LiveView assignments
The way in which the LiveView framework sends information so that programmers can process the data is through callbacks. These are nothing more than functions that run when something happens. The mount/3 callback runs when your LiveView is initialized.
```elixir
defmodule LiveviewWeb.PageLive do
  use LiveviewWeb, :live_view

  def mount(_params, _session, socket) do
    socket = assign(socket, name: "Jakub")
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    Hello {@name}
    """
  end
end
```

- The `mount/3` callback runs when your LiveView is initializing.
- The `socket` data structure contains the state of your LiveView for this user at the moment.
- We were able to add `assigns` using the `assign/2` function, passing the `socket` and the new values.
- The `render/1` function has a shortcut for writing assigns using `@name` instead of `assigns.name`.


# Modifying state with events

For each event in your HTML code, you need a corresponding `def handle_event("your_event", _params, socket)`

```elixir
defmodule LiveviewWeb.PageLive do
  use LiveviewWeb, :live_view

  def mount(_params, _session, socket) do
    socket = assign(socket, name: "Lubien")
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    Hello {@name}

    <input type="button" value="Reverse" phx-click="reverse"/>
    """
  end

  def handle_event("reverse", _params, socket) do
    socket = assign(socket, name: String.reverse(socket.assigns.name))
    {:noreply, socket}
  end
end
```

- By adding `phx-click="event_name"` to an element, you trigger an event named `"event_name"` when it is clicked.
- For each event in your HTML, you need an equivalent `handle_event("event_name", _params, socket)` callback.
- The `mount/3` callback returns `{:ok, socket}`, while `handle_event/3` returns `{:noreply, socket}`.
- If you forget to implement `handle_event/3`, the LiveView will show an `UndefinedFunctionError`.
- If you have the callback but do not handle the received case, you will see a `FunctionClauseError`.








