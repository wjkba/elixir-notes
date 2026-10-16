Adopt LiveView by Lubien

# Fundamentals
## First Live View

`lib/myapp_web/router.ex`
```elixir
scope "/", MyappWeb do
  pipe_through :browser

  get "/", PageController, :home
end
```

## Anatomy of a LiveView
- Mix is the Elixir project compilation tool.
- 'mix setup' is useful to get started on projects you just cloned.
- All LiveViews have a 'render/1' function and always receive an argument called 'assigns'.
- 'use MyappWeb', :live_view adds things at compile time to make your LiveView work properly.


## LiveView assignments
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


## Modifying state with events

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


# HEEx

## HEEx Basics
when using <% %> tag, do note that there is no = after the first %. In HEEx this means "execute this code but do not render the result". As it uses the IO.puts/2 function, you can see the result in your terminal.

```elixir
  def render(assigns) do
    ~H"""
    <h2>Hello {"Lubien"}</h2>
    <h2>Hello {1 + 1}</h2>
    <h2>Hello {"Chris" <> " " <> "McCord"}</h2>
    <h2>Hello <% "King Crimson" |> IO.puts() %></h2>
    """
  end
```

- nil renders nothing

```elixir
 def render(assigns) do
    bg_for_hello_phoenix = "bg-black"
    multiple_attributes = %{style: "color: yellow", class: "bg-black"}

    ~H"""
    <style>
      .color-red { color: red }
      .bg-black { background-color: black }
      .bg-red { background-color: red }
    </style>

    <h2 style="color: red" class="bg-black">Hello World</h2>
    <h2 style="color: white" class={"bg-" <> "red"}>Hello Elixir</h2>
    <h2 class={[bg_for_hello_phoenix, nil, "color-red"]}>Hello Phoenix</h2>
    <h2 {multiple_attributes}>Hello LiveView</h2>
    """
  end
```
In the third example (Hello Phoenix) there is a golden tip: you can pass a list with multiple strings to an attribute and at the end it will be automatically joined and values that are nil will be ignored. The reason this technique is powerful is that it makes it easier to work with variables, as we can see bg_for_hello_phoenix being used.

The last case (Hello LiveView) adds one more way of working with attributes. If you ever need to add attributes dynamically, that is, you don't know exactly which attributes will or won't be included in advance, you can use the syntax of adding an elixir map within the opening HTML tag and HEEx will understand that each key in your map represents an attribute.

## Conditional rendering

```elixir
defmodule LiveviewWeb.PageLive do
  use LiveviewWeb, :live_view

  def mount(_params, _session, socket) do
    socket = assign(socket, show_information?: false)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= if @show_information? do %>
        <p>You're an amazing person!</p>
      <% else %>
        <p>You can't see this message!</p>
      <% end %>
    </div>

    <input type="button" value="Toggle" phx-click="toggle" />
    """
  end

  def handle_event("toggle", _params, socket) do
    socket = assign(socket, show_information?: !socket.assigns.show_information?)
    {:noreply, socket}
  end
end
```

Inside a LiveView, you can do an `if-else` as follows:

- Add a `<%= if condition do %>`. It is important that you use the tag that contains `=`; otherwise, HEEx will understand that this should not be rendered.
- Write any HTML that will be in the case that should be rendered.
- Add an `<% else %>`. Note that there is no `=` this time. If you add it, the code continues to work, but a warning will ask you to remove it.
- Write any HTML for the `else` case.
- Add a `<% end %>`. Again, without `=`.


For cases where you only have `if`, HEEx has a special attribute called `:if`
```elixir
  def render(assigns) do
    ~H"""
    <div>
      <p :if={@show_information?}>You're an amazing person!</p>
    </div>

    <input type="button" value="Toggle" phx-click="toggle" />
    """
  end
```
At the moment there is no special attribute for else so if you only need if it is recommended to use :if when you can put it in a parent tag of the things that enter the condition, otherwise use the first example with if-else as shown above.


```elixir
def mount(_params, _session, socket) do
    socket = assign(socket, show_information?: false)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <p :if={@show_information?}>You're an amazing person!</p>
    </div>

    <input type="button" value="Toggle" phx-click="toggle" />
    """
  end

  def handle_event("toggle", _params, socket) do
    socket = assign(socket, show_information?: !socket.assigns.show_information?)
    {:noreply, socket}
  end
```


cond do:
```elixir
  def mount(_params, _session, socket) do
    socket = assign(socket, temperature_celsius: 30)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      Current temperature: {@temperature_celsius}C
    </div>
    <div>
      <%= cond do %>
        <% @temperature_celsius > 40 -> %>
          <p>🔥 Impossible to live 🔥</p>
        <% @temperature_celsius > 30 -> %>
          <p>Its hot</p>
        <% @temperature_celsius > 20 -> %>
          <p>Kinda cool</p>
        <% @temperature_celsius > 10 -> %>
          <p>Chill</p>
        <% @temperature_celsius > 0 -> %>
          <p>Chill</p>
        <% true -> %>
          <p>❄️⛄️</p>
      <% end %>
    </div>

    <input type="button" value="Increase" phx-click="increase" />
    <input type="button" value="Decrease" phx-click="decrease" />
    """
  end

  def handle_event("increase", _params, socket) do
    socket = assign(socket, temperature_celsius: socket.assigns.temperature_celsius + 10)
    {:noreply, socket}
  end

  def handle_event("decrease", _params, socket) do
    socket = assign(socket, temperature_celsius: socket.assigns.temperature_celsius - 10)
    {:noreply, socket}
  end
```

- For `if` without `else`, you can use the `<%= if condition do %>` block format or the special HEEx attribute `:if={condition}` in an HTML tag.
- For multiple comparisons of a value, you can use `<%= case value do %>`.
- For multiple conditions that don't just involve comparing whether a value matches something, you can use `<%= cond do %>`.
- In all cases, the first tag will always need `=`, and the others won't. If you add `=` to the other tags, LiveView will generate warnings, but everything will work normally.
- If in the first tag you do not add `=`, the HTML code will not be rendered.

## List rendering

The official recommendation from the Phoenix team is that you avoid doing any type of calculation within your render/1 as much as possible. Process your code before assigning them to your socket.
```elixir
  def mount(_params, _session, socket) do
    foods = Enum.filter(["apple", "banana", "carrot"], fn food -> food != "banana" end)
    socket = assign(socket, foods: foods)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <ul>
      <%= for food <- @foods do %>
        <li>{food}</li>
      <% end %>
    </ul>
    """
  end
```

 Just as the if block has the :if version, the for comprehension has its special HEEx attribute :for. 
```elixir
  def mount(_params, _session, socket) do
    foods = Enum.filter(["apple", "banana", "carrot"], fn food -> food != "banana" end)
    socket = assign(socket, foods: foods)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <ul>
      <%= for food <- @foods do %>
        <li>{food}</li>
      <% end %>
    </ul>
    """
  end
```

How can we have list rendering that doesn't consume memory forever and that doesn't re-render when assigns change?

```elixir
  def mount(_params, _session, socket) do
    socket = assign(socket, foods: ["apple", "banana", "carrot"])
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <ul>
      <li :for={food <- @foods}>{food}</li>
    </ul>
    """
  end
```
- We must add a special `phx-update="stream"` attribute to define that the children of this element are part of a stream.
- Inside our `ul`, we kept the special `:for` comprehension, but this time we read the special assign `@streams.foods`.
- Every time a stream is created with `:some_name`, a special assign `@streams.some_name` is generated.

# Events
## phx-value
```elixir
  def mount(_params, _session, socket) do
    socket = assign(socket, temperature_celsius: 30)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      Current temperature: {@temperature_celsius}C
    </div>
    <div>
      <%= cond do %>
        <% @temperature_celsius > 40 -> %>
          <p>🔥 Impossible to live 🔥</p>
        <% @temperature_celsius > 30 -> %>
          <p>Its hot</p>
        <% @temperature_celsius > 20 -> %>
          <p>Kinda cool</p>
        <% @temperature_celsius > 10 -> %>
          <p>Chill</p>
        <% @temperature_celsius > 0 -> %>
          <p>Chill</p>
        <% true -> %>
          <p>❄️⛄️</p>
      <% end %>
    </div>

    <input type="button" value="+5" phx-click="add" phx-value-amount={+5} />
    <input type="button" value="+10" phx-click="add" phx-value-amount={+10} />
    <input type="button" value="-5" phx-click="add" phx-value-amount={-5} />
    <input type="button" value="-10" phx-click="add" phx-value-amount={-10} />
    """
  end

  def handle_event("add", %{"amount" => amount}, socket) do
    amount = String.to_integer(amount)
    socket = assign(socket, temperature_celsius: socket.assigns.temperature_celsius + amount)
    {:noreply, socket}
  end
```

We replaced the `"increase"` and `"decrease"` events with a generic event called `"add"` that receives a `phx-value-amount`, which is a number. The `handle_event/3` callback receives `%{"amount" => "+10"}` as its second parameter, depending on the button clicked. Parameters coming from HTML always come in string format because HTML attributes are strings, so we must convert the number before performing the sum.
- The `phx-value-*` binding can help generalize an event so that it is reusable.
- The data you receive in `handle_event/3` corresponds to the HEEx binding name: `phx-value-test` generates `%{"test" => value}`.
- Values coming from a `phx-value-*` binding are always strings.

## JS.push
The example above can be simplified by using `JS.push/2` directly in the `pxh-click` binding

```elixir
  def render
  (...)
    <input type="button" value="+5" phx-click={JS.push("add", value: %{amount: +5})} />
    <input type="button" value="+10" phx-click={JS.push("add", value: %{amount: +10})} />
    <input type="button" value="-5" phx-click={JS.push("add", value: %{amount: -5})} />
    <input type="button" value="-10" phx-click={JS.push("add", value: %{amount: -10})} />
  end

  def handle_event("add", %{"amount" => amount}, socket) do
    socket = assign(socket, temperature_celsius: socket.assigns.temperature_celsius + amount)
    {:noreply, socket}
  end
```

Code duplication could be avoided by using simple `:for`
```elixir
    <input
      :for={value <- [5, 10, -5, -10]}
      type="button"
      value={"Add #{value}"}
      phx-click={JS.push("add", value: %{amount: value})}
    />
```

## More than one event triggered

```elixir
 def mount(_params, _session, socket) do
    socket = assign(socket, red: 0, blue: 0)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <dl>
      <dt>Red Points</dt>
      <dd>{@red}</dd>

      <dt>Blue Points</dt>
      <dd>{@blue}</dd>
    </dl>

    <input
      type="button"
      value="Red Wins"
      phx-click={JS.push("add_points", value: %{team: :red, amount: +3})}
    />
    <input
      type="button"
      value="Blue Wins"
      phx-click={JS.push("add_points", value: %{team: :blue, amount: +3})}
    /> ?????????
    <input
      type="button"
      value="Draw"
      phx-click={
        JS.push("add_points", value: %{team: :blue, amount: +1})
        |> JS.push("add_points", value: %{team: :red, amount: +1})
      }
    />
    """
  end

  def handle_event("add_points", %{"team" => team, "amount" => amount}, socket) do
    team_atom = String.to_existing_atom(team)
    current_points = socket.assigns[team_atom]
    socket = assign(socket, team_atom, current_points + amount)
    {:noreply, socket}
  end
```

Custom JS Commands and module functions 
```elixir
 def mount(_params, _session, socket) do
    socket = assign(socket, red: 0, blue: 0)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <dl>
      <dt>Red Points</dt>
      <dd>{@red}</dd>

      <dt>Blue Points</dt>
      <dd>{@blue}</dd>
    </dl>

    <input
      type="button"
      value="Red Wins"
      phx-click={add_points(:red, 3)}
    />
    <input
      type="button"
      value="Blue Wins"
      phx-click={add_points(:blue, 3)}
    />
    <input
      type="button"
      value="Draw"
      phx-click={add_points(:red, 1) |> add_points(:blue, 1)}
    />
    """
  end

  defp add_points(js \\ %JS{}, team, amount) do
    JS.push(js, "add_points", value: %{team: team, amount: amount})
  end

  def handle_event("add_points", %{"team" => team, "amount" => amount}, socket) do
    team_atom = String.to_existing_atom(team)
    current_points = socket.assigns[team_atom]
    socket = assign(socket, team_atom, current_points + amount)
    {:noreply, socket}
  end
```

- JS Commands can be chained.
- Using JS Commands, you can trigger more than one event in the same `phx-click` binding.
- Creating custom JS Command functions requires explicitly receiving an optional argument `js \\ %JS{}` and using `js` within the function.

# Navigation

## Your second LiveView
- Every Phoenix application has a Router.
- Routers use pipelines and `scope` blocks to define how certain routes behave.
- In a Router, we can define LiveView routes using the `live/4` macro.
- HTML tags with `.` at the beginning, such as `<.link>`, indicate that the tag is actually a component.
- We must use the `<.link navigate={~p"/route"}>` component in our LiveViews to navigate efficiently between routes.
- Using `sigil_p`, we can write routes so that Phoenix will warn us if they don't exist, allowing us to detect problems during development.

## Route parameters

```elixir
 scope "/", LiveviewWeb do
    pipe_through :browser

    live "/", PageLive, :home
    live "/other", OtherPageLive, :other
    live "/blog/:slug", BlogLive, :index
  end
```

```elixir
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
```

- The `live/4` macro lets you create parameters in the URL using the `:variable_name` format.
- Any parameter defined in the router becomes a key in the `params` map in your LiveView.


## Generic parameters with query string 
```elixir
  def mount(params, _session, socket) do
    admin? = params["admin_mode"] == "secret123"
    socket = assign(socket, :admin?, admin?)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h1>Welcome to my Website!</h1>
    <.link :if={@admin?} navigate={~p"/admin"}>Go to admin panel</.link>
    """
  end
```

Saving the current tab in the url
```elixir
  def mount(params, _session, socket) do
    tab = params["tab"] || "home"
    socket = assign(socket, tab: tab)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= case @tab do %>
        <% "home" -> %>
          <p>You're on my personal page!</p>
        <% "about" -> %>
          <p>Hi, I'm a LiveView developer!</p>
        <% "contact" -> %>
          <p>Mail me to bot [at] company [dot] com</p>
      <% end %>
    </div>

    <.link :if={@tab != "home"} navigate={~p"/tab/home"}>Go to home</.link>
    <.link :if={@tab != "about"} navigate={~p"/tab/about"}>Go to about</.link>
    <.link :if={@tab != "contact"} navigate={~p"/tab/contact"}>Go to contact</.link>
    """
  end
```

When you use <.link navigate={...}>, LiveView understands that you are changing from one LiveView to a different one and need to create a new context. If you know beforehand that a transition goes to the same LiveView, you can use the alternative <.link patch={...}> and the modification between routes will be even more optimized. For this to work correctly, we need to introduce a new callback called handle_params/3. 
Whenever a LiveView is initialized by Phoenix for the first time, it executes mount/3 if it exists and then handle_params/3 if it exists. This way, we can remove mount/3 completely.
```elixir
  def handle_params(params, _uri, socket) do
    tab = params["tab"] || "home"
    socket = assign(socket, tab: tab)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= case @tab do %>
        <% "home" -> %>
          <p>You're on my personal page!</p>
        <% "about" -> %>
          <p>Hi, I'm a LiveView developer!</p>
        <% "contact" -> %>
          <p>Mail me to bot [at] company [dot] com</p>
      <% end %>
    </div>

    <.link :if={@tab != "home"} patch={~p"/"}>Go to home</.link>
    <.link :if={@tab != "about"} patch={~p"/tab/about"}>Go to about</.link>
    <.link :if={@tab != "contact"} patch={~p"/tab/contact"}>Go to contact</.link>
    """
  end
```

- We can take advantage of URLs to persist data in cases such as tabs.
- `handle_params/3` is a callback that is executed right after `mount/3`.
- One way to optimize page changes within the same LiveView is to use `patch` in the `<.link>` components.
- Using `patch` executes `handle_params/3`.


# Components
## Functional components


You can create components in your LiveViews by defining a function that receives assigns and returns HEEx.
```elixir
  def render(assigns) do
    ~H"""
    <.my_button>Default</.my_button>
    <.my_button>Green</.my_button>
    <.my_button>Red</.my_button>
    <.my_button>Yellow</.my_button>
    """
  end

  def my_button(assigns) do
    ~H"""
    <button
      type="button"
      class="text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-blue-600 dark:hover:bg-blue-700 focus:outline-none dark:focus:ring-blue-800"
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
```
- HTML components and tags are distinguished by the presence of a leading `.` in the component name to avoid conflicts.
- In a component, you decide where to render the child nodes using `render_slot(@inner_block)`.
- Your components can reuse code efficiently through attributes.


## Validating components
```elixir
  @doc """
  Renders a button

  ## Examples

      <.my_button>Save data</.my_button>
      <.my_button color="red">Delete account</.my_button>
  """
  attr :color, :string, default: "blue"
  slot :inner_block, required: true

  def my_button(assigns) do
    ~H"""
    <button
      type="button"
      class={"text-white bg-#{@color}-700 hover:bg-#{@color}-800 focus:ring-4 focus:ring-#{@color}-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-#{@color}-600 dark:hover:bg-#{@color}-700 focus:outline-none dark:focus:ring-#{@color}-800"}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
```
If you are interested in only certain colors being accepted by your component, use `values` as follows: `attr :color, :string, default: "blue", values: ~w(blue red yellow green)`. If you want to provide examples without limiting the accepted values, simply change `values` to `examples`.
[`sigil_w`](https://hexdocs.pm/elixir/1.16.2/Kernel.html?utm_source=chatgpt.com#sigil_w/2) provides a simplified way to create lists of strings. For example, `["blue", "green"]` can be written as `~w(blue green)`. With this sigil, you don't need commas or quotation marks; simply place the values inside the parentheses.



To allow the component to receive additional classes, we need to define a new `attr`. Update `page_live.ex` to add a `class` attribute.
```elixir
  attr :color, :string, default: "blue", examples: ~w(blue red yellow green)
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def my_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "text-white bg-#{@color}-700 hover:bg-#{@color}-800 focus:ring-4 focus:ring-#{@color}-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-#{@color}-600 dark:hover:bg-#{@color}-700 focus:outline-none dark:focus:ring-#{@color}-800",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
```

As you can see, our button currently just works as type="button". If we want to be able to change the type to "submit" or "reset" we would have to create a new attr. This manual process of creating an attr gets repetitive very quickly. If you just want to pass through all other attributes coming from using the component, HEEx has a solution. Update page_live.ex to support global attributes
```elixir
  attr :color, :string, default: "blue", examples: ~w(blue red yellow green)
  attr :class, :string, default: nil
  attr :rest, :global, default: %{type: "button"}, include: ~w(type style)
  slot :inner_block, required: true

  def my_button(assigns) do
    ~H"""
    <button
      class={[
        "text-white bg-#{@color}-700 hover:bg-#{@color}-800 focus:ring-4 focus:ring-#{@color}-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-#{@color}-600 dark:hover:bg-#{@color}-700 focus:outline-none dark:focus:ring-#{@color}-800",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
```

- Using `attr/3`, you can document and enhance your component:
  - You can mark an attribute as `required`.
  - You can set a default value if none is provided using `default`.
  - You can restrict the possible values using `values`.
  - You can provide examples of possible values using `examples`.
  - You can capture all additional properties using an `attr` of type `:global`.

## Components from other modules

using components from other pages:
```elixir
defmodule LiveviewWeb.OtherPageLive do
  use LiveviewWeb, :live_view
  alias LiveviewWeb.PageLive

  def render(assigns) do
    ~H"""
    <h1>OtherPageLive</h1>
    <PageLive.my_button color="blue">
      My other button
    </PageLive.my_button>
    """
  end
end
```

- You can use components from other modules using the `<MyappWeb.ModuleName.component_name>` syntax.
- You can use aliases to shorten module function calls, such as `alias MyappWeb.ModuleName`, allowing you to use the `<ModuleName.component_name>` syntax.
- If a component is used in many places throughout the application, consider placing it in `CoreComponents`.
- Behind the scenes, `use MyappWeb, :something` inserts code from `MyappWeb`'s `def something() do` into your module, giving you access to the tools needed to do your work.


## Multiple slots

custom slots:
```elixir
  slot :inner_block, required: true

  def hero(assigns) do
    ~H"""
    <div class="bg-gray-800 text-white py-20">
      <div class="container mx-auto text-center">
        <h1 class="text-4xl font-bold">{render_slot(@inner_block)}</h1>
        <p class="mt-4 text-lg">My personal website</p>
        <.link
          class="mt-8 bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded mr-2"
          navigate={~p"/"}
        >
          Homepage
        </.link>
        <.link
          class="mt-8 bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded"
          navigate={~p"/other"}
        >
          Get Started
        </.link>
      </div>
    </div>
    """
  end
```

usage:
```elixir
  def render(assigns) do
    ~H"""
    <.hero>OtherPageLive</.hero>
    <my_button color="blue">
      My other button
    </my_button>
    """
  end
```

- Components can have more than one slot.
- Named slots can be defined using `<:name>Content</:name>` and rendered using `{render_slot(@name)}`.
- Any HEEx content outside named slots falls into the `@inner_block` slot.


## Slots with attributes

if slots are lists we can do loops and if each slot is a map, we can get properties from them!
```elixir
  slot :title do
    attr :class, :string
  end

  slot :subtitle
  slot :inner_block

  def hero(assigns) do
    ~H"""
    <div class="bg-gray-800 text-white py-20">
      <div class="container mx-auto text-center">
        <h1 :for={title_slot <- @title} class={["text-4xl font-bold", Map.get(title_slot, :class)]}>
          {render_slot(title_slot)}
        </h1>
        <p class="mt-4 text-lg">{render_slot(@subtitle)}</p>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
```

- The component itself isn't much different from what you've seen before. We use a loop with `:for`. For each element, we use the `render_slot/2` function, passing the current item in the loop as the second argument.
- When a second argument is passed to `render_slot/2`, we can use the special attribute `:let={var}` in the slot definition to store the current looped element in `var`. This simplifies a component that works with loops and keeps the LiveView's `render/1` clean.

```elixir
  def render(assigns) do
    ~H"""
    <.hero>
      <:title class="text-red-500">IndexLive</:title>
      <:subtitle>Welcome to my personal website!</:subtitle>
      <.link
        class="mt-8 bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded"
        navigate={~p"/other"}
      >
        Get Started
      </.link>
    </.hero>
    This is my homepage
    """
  end
```

- You can simplify loops by creating components.
- Slots can receive loop variables by passing them as the second argument of `render_slot/2` and receiving them in the slot using `:let={var_name}`.
- Using slots and components makes LiveView code cleaner.


# Forms

## The simplest form of all

```elixir
  def handle_event("create_product", %{"product" => product_params}, socket) do
    IO.inspect({"Form submitted!!", product_params})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <form phx-submit="create_product" class="flex flex-col max-w-96 mx-auto p-24">
        <h1 class="text-blue-500">Creating a product</h1>
        <input type="text" name="product[name]" placeholder="Name" />
        <input type="text" name="product[description]" placeholder="Description" />
        <button type="submit">Send</button>
      </form>
    </div>
    """
  end
```

When we have a HTML form with inputs product[name] and product[description] this generates an equivalent map in the format %{"product" => %{"name" => "", "description" => ""}}. This makes it easier for us to retrieve this value in our handle_event/3.


.form way:
```elixir
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
        <h1>Creating a product</h1>
        <input type="text" id={@form[:name].id} name={@form[:name].name} placeholder="Name" />

        <input
          type="text"
          id={@form[:description].id}
          name={@form[:description].name}
          placeholder="Description"
        />

        <button type="submit">Send</button>
      </.form>
    </div>
    """
  end
```

- In the HEEx code, the first difference is that we replaced the HTML tag `<form>` with the component `<.form>`, passing the assign `for={@form}`. That's all this component needs!
- Further below, we modified our `input` tags to receive form fields in the format `@form[:name]`. Each of these represents a `Phoenix.HTML.FormField`, and we use the field's `id` and `name` properties in the attributes with the same names.
- You might be thinking, "My code has become more verbose. What's the advantage?" The motivation is simpler than it seems: we can componentize our `input` tags!

```elixir
  attr :field, Phoenix.HTML.FormField, required: true
  attr :type, :string, default: "text"
  attr :rest, :global, include: ~w(placeholder type)

  def my_input(assigns) do
    ~H"""
    <input type={@type} id={@field.id} name={@field.name} {@rest} />
    """
  end
```


```elixir
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
```

- LiveView forms use the `phx-submit` binding to trigger a `handle_event/3` callback with the respective event name.
- Phoenix prefers the format `parent_name[child_name]` for input names to make it easier to manage which form contains which data. This generates maps like `%{"parent_name" => %{"child_name" => ""}}` in `phx-submit` events.
- The preferred approach for creating forms is to use the `<.form>` component instead of the `<form>` tag.
- To prepare data in the `Phoenix.HTML.Form` format, the `to_form/2` function converts data, such as `to_form(%{name: ""}, as: :product)`, into the appropriate format.
- We prefer to add `as: :name_of_parent` as an option to `to_form/2` to follow the Phoenix convention for the `name` attributes of our `input` tags.
- Using forms in the `Phoenix.HTML.Form` format makes it easier to create components for inputs.

## Validations
Just like `phx-submit`, the `phx-change` binding works on forms but it is triggered every time any data in a form is modified

```elixir
  def my_input(assigns) do
    ~H"""
    <input type="text" id={@field.id} name={@field.name} value={@field.value} {@rest} />
    <div :for={msg <- @field.errors} class="text-red-500 py-2">{msg}</div>
    """
  end
```


```elixir
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

  def handle_event("validate_product", %{"product" => product_params}, socket) do
    errors = []

    errors =
      if product_params["name"] == "" do
        Keyword.put(errors, :name, "can't be blank")
      else
        errors
      end

    errors =
      if product_params["description"] == "" do
        Keyword.put(errors, :description, "can't be blank")
      else
        errors
      end

    form = to_form(product_params, as: :product, errors: errors)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("create_product", %{"product" => product_params}, socket) do
    IO.inspect({"Form submitted!!", product_params})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-grey-100">
      <.form
        for={@form}
        phx-change="validate_product"
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

```

- `phx-change` is a binding that runs every time the form changes. It triggers a `handle_event/3` callback similar to that of `phx-submit`.
- You can use `to_form/3` to add validation errors to your form by passing them in the options.
- It is the responsibility of the `<.input>` component to render errors and display the current value of the form field if it is modified on the server.
- Fortunately, you don't need to create the `<.input>` component — `CoreComponents` is already generated for you and available in every LiveView via `use MyappWeb, :live_view`.

## Simplifying everything with Ecto 
```elixir
defmodule Liveview.Products.Product do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string, default: ""
    field :description, :string, default: ""
  end

  def changeset(product, params \\ %{}) do
    product
    |> cast(params, [:name, :description])
    |> validate_required([:name, :description])
  end
end
```

1. What embedded schema essentially does is say that a Struct Product starts as %Product{name: "", description: ""} with its DSL.

2. An `Ecto.Schema` with at least one `changeset/2` function is a given. These functions define how data is validated. Instead of handling validation in LiveView, which makes code messy and difficult to reuse, Phoenix projects typically validate data in `changeset/2` functions within an `Ecto.Schema`.
  We receive two arguments: the product and optional parameters (defaulting to `%{}`). We then use pipes to transform the data as follows:
  - We start with a `%Product{name: "", description: ""}` struct, since our form begins with an empty `%Product{}`.
  - Using [`cast/4`](https://hexdocs.pm/ecto/Ecto.Changeset.html?utm_source=chatgpt.com#cast/4), we transform the `%Product{}` into an `%Ecto.Changeset{}`, accepting only the `:name` and `:description` parameters.
  - Using [`validate_required/3`](https://hexdocs.pm/ecto/Ecto.Changeset.html?utm_source=chatgpt.com#validate_required/3), we validate that both `:name` and `:description` are present.



Using changesets in LiveView:
```elixir
defmodule MyappWeb.PageLive do
  # ...

  def mount(_params, _session, socket) do
    form =
      Product.changeset(%Product{})
      |> to_form()

    {:ok, assign(socket, form: form)}
  end

  def handle_event("validate_product", %{"product" => product_params}, socket) do
    form =
      Product.changeset(%Product{}, product_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  # ...
end
```

- We can use `Ecto.Schema` to easily create a `Struct`. Since we are not working with a database yet, we use `embedded_schema` and `fields` to store data only in memory.
- We can use `Ecto.Changeset` to validate user data before it enters our struct.
- Usually, an `Ecto.Schema` has one or more `changeset/2` functions to define how its data is validated, called as `Product.changeset(%Product{}, params)`.
- Our LiveViews become cleaner when we separate validation logic from UI logic.

