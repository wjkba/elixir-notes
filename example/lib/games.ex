defmodule Games do
  def get do
    %{name: "Diablo 4", in_stock: false, price: 100}
  end

  def get_all do
    [
      %{name: "Diablo 4", in_stock: false, price: 100},
      %{name: "Elden Ring", in_stock: true, price: 60},
      %{name: "Cyberpunk 2077", in_stock: true, price: 50},
      %{name: "Baldur's Gate 3", in_stock: true, price: 70}
    ]
  end

  def filter_games(game_list) do
    Enum.filter(game_list, &filter/1)
  end

  defp filter(game) do
    game.in_stock && game.price <= 50
  end

  def print_list(game_list) do
    Enum.map(game_list, fn game ->
      "#{game.name} is #{if game.in_stock, do: "In stock", else: "Not available"}"
    end)
  end

  def print(game) do
    Enum.each(game, fn {key, value} -> IO.puts("#{key}: #{value}") end)
  end

  def purchase(game) do
    case validate_purchase(game) do
      {:error, reason} -> "Error: #{reason}"
      {:ok, _} -> "Sueccessful purchase"
    end
  end

  defp validate_purchase(game) do
    cond do
      !game.in_stock -> {:error, "Game not available for purchase"}
      game.price > 50 -> {:error, "Too expensive! Can't buy"}
      true -> {:ok, "Proceed with the purchase!"}
    end
  end
end
