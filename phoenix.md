# Directory structure
assets - frontend files, js, css
config
deps - node_modules equivalent
lib - source code src equivalent
  lib/app_name - business domain
  lib/app_name_web - frontend
priv - files needed of production but not part of source code
priv/gettext - localisation
mix.exs - package.json equvialent
mix.lock - stay away

# Request life-cycle

inside 'router.ex'
```elixir
  scope "/", ShopWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/products", ProductController, :index
  end
```

'lib/shop_web/controllers/product_controller.ex'
```elixir
defmodule ShopWeb.ProductController do
  use ShopWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
```

'lib/shop_web/controllers/product_html.ex'
```elixir
defmodule ShopWeb.ProductHTML do
  use ShopWeb, :html

  # assigns is similar to react props
  def index(assigns) do
    ~H"""
    <h1>Product listing page</h1>
    """
  end
end
```

mozna rozdzielic html do innego pliku
```elixir
defmodule ShopWeb.ProductHTML do
  use ShopWeb, :html

  embed_templates "product_html/*"
end
```

i stworzyc 'lib/shop_web/controllers/product_html/index.html.heex'


# Plug
specification for composable modules in web applications
it's pretty much a middleware

grabs connection -> do whatever you want -> pass to another plug



function plug accepts two parameters - conn and opts
do whaterver you want as long as you return conn at the end

```elixir
def check_promo_code(%Plug.Conn{} = conn, _opts) do
  # stuff
  conn
end
```



assign assigns value to a variable that is bound to connection and can be accessed from any page

```elixir
def check_promo_code(%Plug.Conn{} = conn, _opts) do
    IO.inspect(conn.params)

    promo_code = conn.params["promo"]

    if promo_code == "secret-code" do
      IO.inspect("Promo is true")
      assign(conn, :promo, true)
    else
      assign(conn, :promo, false)
    end
  end
```

same logic as above but elixir way

```elixir
  def check_promo_code(%Plug.Conn{:params => %{"promo" => "secret-code"}} = conn, _opts) do
    assign(conn, :promo, true)
  end

  def check_promo_code(%Plug.Conn{} = conn, _opts) do
    assign(conn, :promo, false)
  end
```


```elixir
<h1>HEEx is working</h1>
<p :if={@promo}>You have a promotional code</p>
```

# Module plug
przkyładowy plug
`lib/shop_web/plugs/set_console.ex`
```elixir
defmodule ShopWeb.Plugs.SetConsole do
  def init(opts), do: opts

  def call(%Plug.Conn{} = conn, opts) do
    IO.inspect("Module plug is working")
    IO.inspect("OPTS: " <> opts)
    conn
  end
end
```

`lib/shop_web/router.ex`
```elixir
  alias ShopWeb.Plugs

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShopWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Plugs.SetConsole, "pc"
  end
```

działający plug z elixir magic pattern matching i guards
```elixir
defmodule ShopWeb.Plugs.SetConsole do
  import Plug.Conn

  @valid_consoles ["pc, xbox, playstation, nintendo"]

  def init(opts), do: opts

  def call(%Plug.Conn{:params => %{"console" => console}} = conn, _opts)
      when console in @valid_consoles do
    conn
    |> assign(:console, console)
    |> put_resp_cookie("console", console, max_age: 60 * 60 * 24 * 30)
  end

  def call(%Plug.Conn{:cookies => %{"console" => console}} = conn, _opts)
      when console in @valid_consoles do
    conn
    |> assign(:console, console)
  end

  def call(%Plug.Conn{} = conn, default_console) do
    conn
    |> assign(:console, default_console)
  end
end
```



