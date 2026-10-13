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


