# Introduction
## string concatenate
<>

## atoms
:title - named string


## types
there is no null, instead we have nil

# Functional programming
w javascript da sie wywolywac metody na stringach np "test".toUpperCase
w elixirze string to po prostu primitive nie obiekt i nie ma zadnych metod stad String.toUpperCase("test")
(expand a little bit on it)

## immutability
there is no mutability
```elixir
iex> list = [1,2,3]
[1, 2, 3]
iex> list
[1, 2, 3]
iex> list ++ [999, 1_000]
[1, 2, 3, 999, 1000]
iex> list
[1, 2, 3]
iex>
```
zwrotka funkcji append nie jest nowa lista, nie zmienia list
nie ma wiec szans na zmiane wartosci zmiennej przez przypadek, to jest fajne

mozna zdefiniowac list2=list, ale zmiana list nie zmienia list2
```elixir
iex> list = [1,2,3]
[1, 2, 3]
iex> list2 = list
[1, 2, 3]
iex> list = list++[4,5]
[1, 2, 3, 4, 5]
iex> list
[1, 2, 3, 4, 5]
iex> list2
[1, 2, 3]
iex>
```
list i list 2 są niezależne

# Lists
iex> [1,2,3]
[1, 2, 3]

lista to linked list

adresy w pamięci mogą być wszędzie, nie są sekwencyjne jak w javascript
[1, addr2] -> [2,addr3] -> [3,x]

czyli nie mozna tak po prostu po indexie wybrac list[2]

dodawanie wartosci na pierwsze miesjce, przykład taniej operacji:
```elixir
iex> list = [2,3,4]
[2, 3, 4]
iex> [1] ++ list
[1, 2, 3, 4]
```

dodawanie wartości na koniec, to przykład kosztownej operacji bo trzeba przejsć przez całą listę
```elixir
iex> list ++ [999]
[2, 3, 4, 999]
iex>
```

## head&tail
```elixir
iex> hd(list)
2
iex> hd list
2
iex>
```
nawiasy są opcjonalne

```elixir
iex> hd(list)
2
iex> tl(list)
[3, 4]
iex>
```
tail nie jest ostatnim elementem, to reszta po headzie
hd i tl nie potrzebują Modułu bo to Kernel module, nie trzeba Kernel.hd()

ostatni element przy użyciu List module
```elixir
iex> List.last(list)
4
iex>
```

## Enum
```elixir
iex> list
[2, 3, 4]
iex> Enum.concat(list, [8,9])
[2, 3, 4, 8, 9]
iex>
```

# Tuples

## Function arity
specifies how many arguments the funciton is expecting e.g.
```elixir
cp/2
```

what about '!' ?
```elixir
cd!2
```
exclamation mark at the end raises an error
functions without exclamatin mark return a tupple {:error, reason}


question mark at the end returns a boolean

## Tuples
Tuple once defined is fixed
cant do operations like adding in lists

tuples are saved sequentially in memory

można odczytywac wartości tupli indeksami
```elixir
iex> elem({"test",5,10,15},1)
5
iex> elem({"test",5,10,15},0)
"test"
iex>
```

Tupli najczęściej używa się do czytania wyników function calls

Kiedy używamy np. File.read() na pliku to wynikiem jest tuple z atomem-statusem operacji i content pliku
```elixir
iex> File.read("hello.txt")
{:ok, ""}
```

```elixir
iex> File.read("i-dont-exist.txt")
{:error, :enoent}
```

Niżej częsty pattern w elixirze, case i czytanie wyników zwrotki funkcji tuple
```elixir
case my_function() do
  {:ok, value} -> IO.puts(value)
  {:error, reason} -> IO.puts("Error: #{reason}")
end
```

# Keyword lists
Keyword list is a way of passing optional parameters into a function'
```elixir
iex> String.split("1      2      3", " ", trim: true)
["1", "2", "3"]
iex>
```

jesli to ostatni argument w funkcji to mozna uzyc trim: true
[trim: true] to tak na prawde [{:trim, true}]

## Keyword.get
```elixir
iex> keyword = [trim: true]
[trim: true]
iex> Keyword.get(keyword, :trim)
true
iex> Keyword.get(keyword, :invalid)
nil
iex>
```

# Maps
```elixir
iex> map = %{"name" => "kuba", :age => 99, 1 => false}
%{1 => false, :age => 99, "name" => "kuba"}
iex> map[1]
false
iex> map["name"]
"kuba"
iex> map[:age]
99
iex>
```

prostszy syntax:
```elixir
iex> map = %{name: "kuba", age: 26}
%{name: "kuba", age: 26}
iex> map.name
"kuba"
iex> map.age
26
iex>
```

Map.get z default value:
```elixir
iex> map
%{name: "kuba", age: 99}
iex> Map.get(map, "profession", "student")
"student"
iex>
```

Map.put
```elixir
iex> map
%{name: "kuba", age: 99}
iex> map_new = Map.put(map, :profession, "student")
%{name: "kuba", age: 99, profession: "student"}
iex> map_new
%{name: "kuba", age: 99, profession: "student"}
iex>
```

change map values
```elixir
iex> map_new
%{name: "kuba", age: 99, profession: "student"}
iex> %{map_new | name: "Adam", age: 50}
%{name: "Adam", age: 50, profession: "student"}
iex>
```










# Mix

mix.exs to odpowiednik package.json

lib to odpowiednik src? (dziwne)

.exs - skrypty
.ex - pliki do kompilacji


# Modules and funcitons

## Modules
Convention is one module per file. Name of the file =  name of the module
```elixir
defmodule Users do
end
```

for nested modules, folders inside of lib:
Foldername.Filename
dir: lib/helpers:
```elixir
defmodule Helpers.Format do
end
```


## Functions
```elixir
def new do
end
```

last line in function is return


module can have multiple functions named the same, function arity based on arguments:
```elixir
defmodule Users do
  def new(name, age) do
    %{name: name, age: age}
  end

  def new do
    %{name: "John Doe", age: 30}
  end
end
```

```elixir
Users.new/2
Users.new/0
```

## private function
```elixir
  def new do
    generate_default_user()
  end

  defp generate_default_user do
    %{name: "John Doe", age: 30}
  end

```

shorter syntax:
```elixir
  def new, do: generate_default_user()
```

# Import and alias
Jak wywołać funkcje na module z innego modułu?
```elixir
defmodule Users do
  import Helpers.Format

  def new(name, age) do
    formatted_name = trim_text(name)
    %{name: formatted_name, age: age}
  end
end

```

import Helpers.Format importuje wszystkie funkcje z tego modułu, można po prostu użyć trim_text

import konkretnych funkcji
```elixir
defmodule Users do
  import Helpers.Format, only: [trim_text: 1]

  def new(name, age) do
    formatted_name = trim_text(name)
    %{name: formatted_name, age: age}
  end
end
```

alias:
```elixir
defmodule Users do
  alias Helpers.Format, as: Alias

  def new(name, age) do
    formatted_name = Alias.trim_text(name)
    %{name: formatted_name, age: age}
  end
end
```

# Module attributes

Calculated at compile time

@moduledoc - for modules
@doc - for functions


# Pipe operator
```elixir
  def generate_slug(text) do
    text
    |> String.trim()
    |> String.downcase()
    |> String.replace(" ", "-")
  end
```

# Debugging
IO.inspect() - console.log equivalent
dbg() - bardziej szczegółowe logi, z poprzednimi wartościami i lokalizacją kodu
można odplaić iex --dbg pry -S mix


# Pattern matching
## tuple prosty przykład
```elixir
iex> user = {"Jakub", 26}
{"Jakub", 26}
iex> {name, age} = user
{"Jakub", 26}
iex> name
"Jakub"
iex> age
26
iex> 
```


```elixir
iex(13)> {"Jakub", age2} = user
{"Jakub", 26}
iex(14)> age2
26
```

pattern matching file.read example
```elixir
iex(14)> File.read("test.txt")
{:ok, "Lorem ipsum\n"}
iex(15)> {:ok, result} = File.read("test.txt")
{:ok, "Lorem ipsum\n"}
iex(16)> result
"Lorem ipsum\n"
```

errors
```elixir
iex(17)> {:error, reason} = File.read("wrong.txt")
{:error, :enoent}
iex(18)> reason
:enoent
```

lists
```elixir
iex(2)> list = [1,2,3]
[1, 2, 3]
iex(3)> [_, second, third] = list
[1, 2, 3]
iex(4)> first
error: undefined variable "first"
iex(4)> second
2
iex(5)> third
3
```

map matching
```elixir
iex(7)> user = %{name: "Jakub", age: 30}
%{name: "Jakub", age: 30}
iex(8)> %{name: name2, age: age2} = user
%{name: "Jakub", age: 30}
iex(9)> name2
"Jakub"
iex(10)> age2
30
```

zapis w name i age, nie ma skrotu jak w js %{name,age} = user nie działa
```elixir
iex(12)> %{name: name, age: age} = user
%{name: "Jakub", age: 30}
```

## Multi-clause functions
```elixir
defmodule Users do
  alias Helpers.Format

  def new("Jakub", age) do
    %{name: "Jakub", age: age, is_cool: true}
  end

  # new/2
  def new(name, age) do
    formatted_name = Format.trim_text(name)
    %{name: formatted_name, age: age, is_cool: false}
  end
end

```
dwie funkcje w jednym module nazwane tak samo, ważna jest tutaj kolejność, najpierw sprawdzamy name to "Jakub"

# Guards

```elixir
defmodule Users do
  alias Helpers.Format

  def new(name, age) when age >= 18 do
    formatted_name = Format.trim_text(name)
    %{name: formatted_name, age: age, is_cool: false, can_drink: true}
  end

  def new(name, age) do
    formatted_name = Format.trim_text(name)
    %{name: formatted_name, age: age, is_cool: false, can_drink: false}
  end
end
```
guardy można stawiać przy argumentach, kolejność też tutaj ważna, najpierw age check potem default(else)


when,and
```elixir
  def new(name, age) when is_number(age) and age >= 18 do
    formatted_name = Format.trim_text(name)
    %{name: formatted_name, age: age, is_cool: false, can_drink: true}
  end

  def new(name, age) when is_number(age) do
    formatted_name = Format.trim_text(name)
    %{name: formatted_name, age: age, is_cool: false, can_drink: true}
  end

  def new(_,_) do
    IO.puts("Age is invalid")
  end
```

# Conditionals

przykład nested if else, słabe rozwiązanie
```elixir
def validate_purchase(game) do
    if(!game.in_stock) do
      {:error, "Game not available for purchase"}
    else
      if(game.price > 50) do
        {:error, "Too expensive, cant buy"}
      else
        {:ok, "Proceed with the purchase"}
      end
    end
  end
```

zamiast tego można użyć cond:
```elixir
    cond do
      !game.in_stock -> {:error, "Game not available for purchase"}
      game.price > 50 -> {:error, "Too expensive! Can't buy"}
      true -> {:ok, "Proceed with the purchase!"}
    end

```

## Case
pattern matching from a function call, catching errors and ok:
```elixir
defmodule Games do
  def get do
    %{name: "Diablo 4", in_stock: false, price: 100}
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
```

# Enums


np. Enum.filter - pierwszy argument to struktura danych (lista) a drugi to cos takiego jak callback function, ktora odpala sie na kazdym elemencie listy

```elixir
  def filter_games(game_list) do
    Enum.filter(game_list, fn game -> game.in_stock && game.price <= 50 end)
  end

```

przykład mapy
```elixir
  def print_list(game_list) do
    Enum.map(game_list, fn game ->
      "#{game.name} is #{if game.in_stock, do: "In stock", else: "Not available"}"
    end)
  end
```

przykład pętli przez mape, można robić pattern matching
```elixir
  def print(game) do
    Enum.each(game, fn {key, value} -> IO.puts("#{key}: #{value}") end)
  end
```

# Anonymous functions

```elixir
  def filter_games(game_list) do
    Enum.filter(game_list, &(&1.in_stock && &1.price <= 50))
  end
```

dla większych funkcji, można użyć named function
```elixir
  def filter_games(game_list) do
    Enum.filter(game_list, &filter/1)
  end

  defp filter(game) do
    game.in_stock && game.price <= 50
  end
```


# Structs

definiowanie struct
```elixir
  defstruct [:name, :email]
```

z domyślnymi wartościami
```elixir
  defstruct name: "jakub", email: "jakub@gmail.com"
```

wymagaj kluczy
```elixir
  @enforce_keys [:name]
  defstruct [:name, :email]
```

użycie na mapach:
```elixir
  @enforce_keys [:name]
  defstruct [:name, :age, :is_cool, :can_drink]

  def new("Jakub", age) do
    %Users{name: "Jakub", age: age, is_cool: true, can_drink: true}
  end
```

# ExUnit
folder 'test' używany jest przez mix


```bash
mix test
```
mix odpala 'ExUnit.Start' a potem odpala reszte pików testowych w folderze


```elixir
defmodule UsersTest do
  use ExUnit.Case, async: true
end
```
'use' to makro, kod jest tutaj wstrzykiwany
'async: true' pozwala na rownolegle testy


```elixir
defmodule UsersTest do
  use ExUnit.Case, async: true

  describe "Users module" do
    test "new/0" do
      default_user = Users.new()
      refute default_user.can_drink
    end
  end
end
```
refute - oczekuje false, assert - oczekuje true


```elixir
  setup_all do
    %{user_name: "Jakub"}
  end

  describe "Users module" do
    test "new/0", context do
      IO.inspect(context)
      default_user = Users.new()
      refute default_user.can_drink
    end
  end
```
context daje szczególowe metadane
setup_all wstrzykuje dane do kontekstu


'mix test --cover'
cover review z dokumentacją, podsumowanie testów w html i ładne formatowanie terminal
