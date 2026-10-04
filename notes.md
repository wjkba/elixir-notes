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
"
iex(7)> list = [1,2,3]
[1, 2, 3]
iex(8)> list
[1, 2, 3]
iex(9)> list ++ [999, 1_000]
[1, 2, 3, 999, 1000]
iex(10)> list
[1, 2, 3]
iex(11)>
"
zwrotka funkcji append nie jest nowa lista, nie zmienia list
nie ma wiec szans na zmiane wartosci zmiennej przez przypadek, to jest fajne

mozna zdefiniowac list2=list, ale zmiana list nie zmienia list2
"
iex(2)> list = [1,2,3]
[1, 2, 3]
iex(3)> list2 = list
[1, 2, 3]
iex(4)> list = list++[4,5]
[1, 2, 3, 4, 5]
iex(5)> list
[1, 2, 3, 4, 5]
iex(6)> list2
[1, 2, 3]
iex(7)>
"
list i list 2 są niezależne

# Lists
iex(1)> [1,2,3]
[1, 2, 3]

lista to linked list

adresy w pamięci mogą być wszędzie, nie są sekwencyjne jak w javascript
[1, addr2] -> [2,addr3] -> [3,x]

czyli nie mozna tak po prostu po indexie wybrac list[2]

dodawanie wartosci na pierwsze miesjce, przykład taniej operacji:
"
iex(2)> list = [2,3,4]
[2, 3, 4]
iex(3)> [1] ++ list
[1, 2, 3, 4]
"

dodawanie wartości na koniec, to przykład kosztownej operacji bo trzeba przejsć przez całą listę
"
iex(4)> list ++ [999]
[2, 3, 4, 999]
iex(5)>
"

## head&tail
"
iex(8)> hd(list)
2
iex(9)> hd list
2
iex(10)>
"
nawiasy są opcjonalne

"
iex(12)> hd(list)
2
iex(13)> tl(list)
[3, 4]
iex(14)>
"
tail nie jest ostatnim elementem, to reszta po headzie
hd i tl nie potrzebują Modułu bo to Kernel module, nie trzeba Kernel.hd()

ostatni element przy użyciu List module
"
iex(14)> List.last(list)
4
iex(15)>
"

## Enum
"
iex(18)> list
[2, 3, 4]
iex(19)> Enum.concat(list, [8,9])
[2, 3, 4, 8, 9]
iex(20)>
"

# Tuples

## Function arity
specifies how many arguments the funciton is expecting e.g.
"
cp/2
"

what about '!' ?
"
cd!2
"
exclamation mark at the end raises an error
functions without exclamatin mark return a tupple {:error, reason}


question mark at the end returns a boolean

## Tuples
Tuple once defined is fixed
cant do operations like adding in lists

tuples are saved sequentially in memory

można odczytywac wartości tupli indeksami
"
iex(9)> elem({"test",5,10,15},1)
5
iex(10)> elem({"test",5,10,15},0)
"test"
iex(11)>
"

Tupli najczęściej używa się do czytania wyników function calls

Kiedy używamy np. File.read() na pliku to wynikiem jest tuple z atomem-statusem operacji i content pliku
"
iex(1)> File.read("hello.txt")
{:ok, ""}
"

"
iex(2)> File.read("i-dont-exist.txt")
{:error, :enoent}
"

Niżej częsty pattern w elixirze, case i czytanie wyników zwrotki funkcji tuple
"
case my_function() do
  {:ok, value} -> IO.puts(value)
  {:error, reason} -> IO.puts("Error: #{reason}")
end
"

# Keyword lists
Keyword list is a way of passing optional parameters into a function'
"
iex(5)> String.split("1      2      3", " ", trim: true)
["1", "2", "3"]
iex(6)>
"

jesli to ostatni argument w funkcji to mozna uzyc trim: true
[trim: true] to tak na prawde [{:trim, true}]

## Keyword.get
"
iex(9)> keyword = [trim: true]
[trim: true]
iex(10)> Keyword.get(keyword, :trim)
true
iex(11)> Keyword.get(keyword, :invalid)
nil
iex(12)>
"

# Maps
"
iex(2)> map = %{"name" => "kuba", :age => 99, 1 => false}
%{1 => false, :age => 99, "name" => "kuba"}
iex(3)> map[1]
false
iex(4)> map["name"]
"kuba"
iex(5)> map[:age]
99
iex(6)>
"

prostszy syntax:
"
iex(3)> map = %{name: "kuba", age: 26}
%{name: "kuba", age: 26}
iex(4)> map.name
"kuba"
iex(5)> map.age
26
iex(6)>
"

Map.get z default value:
"
iex(10)> map
%{name: "kuba", age: 99}
iex(11)> Map.get(map, "profession", "student")
"student"
iex(12)>
"

Map.put
"
iex(24)> map
%{name: "kuba", age: 99}
iex(25)> map_new = Map.put(map, :profession, "student")
%{name: "kuba", age: 99, profession: "student"}
iex(26)> map_new
%{name: "kuba", age: 99, profession: "student"}
iex(27)>
"

change map values
"
iex(36)> map_new
%{name: "kuba", age: 99, profession: "student"}
iex(37)> %{map_new | name: "Adam", age: 50}
%{name: "Adam", age: 50, profession: "student"}
iex(38)>
"










# Mix

mix.exs to odpowiednik package.json

lib to odpowiednik src? (dziwne)

.exs - skrypty
.ex - pliki do kompilacji











