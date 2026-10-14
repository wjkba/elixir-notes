defmodule Users do
  @enforce_keys [:name]
  defstruct [:name, :age, :is_cool, :can_drink]

  alias Helpers.Format, as: Format

  def check(%Users{} = _user), do: true
  def check(_user), do: false

  def new do
    %Users{name: "Guest", age: 0, is_cool: false, can_drink: false}
  end

  def new("Jakub", age) do
    %Users{name: "Jakub", age: age, is_cool: true, can_drink: true}
  end

  def new(user) when user.age >= 18 do
    formatted_name = Format.trim_text(user.name)
    %Users{name: formatted_name, age: user.age, is_cool: false, can_drink: true}
    # generate_default_user(formatted_name, age, origin, sex)
  end

  def new(user) do
    formatted_name = Format.trim_text(user.name)
    %Users{name: formatted_name, age: user.age, is_cool: false, can_drink: false}
    # generate_default_user(formatted_name, age, origin, sex)
  end

  # defp generate_default_user(name, age, origin, sex)
  #      when is_binary(name) and
  #             is_integer(age) and
  #             is_binary(origin) and
  #             is_binary(sex) do
  #   %{name: name, age: age, origin: origin, sex: sex}
  #   "Hello #{name}, you are #{age} years old, you are from #{origin}, and you are a #{sex}"
  # end
end
