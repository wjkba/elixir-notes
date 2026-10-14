defmodule UsersTest do
  use ExUnit.Case, async: true

  setup_all do
    %{user_name: "Jakub"}
  end

  describe "Users module" do
    test "new/0", %{name: user_name} do
      IO.inspect(user_name)
      default_user = Users.new()
      refute default_user.can_drink
    end

    test "new/2 with name" do
      jakub = Users.new("Jakub", 99)
      assert jakub.is_cool == true
    end
  end
end
