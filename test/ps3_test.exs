defmodule PS3Test do
  use ExUnit.Case

  @moduletag :unit

  doctest PS3

  test "module exists" do
    assert Code.ensure_loaded?(PS3)
  end
end
