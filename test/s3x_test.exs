defmodule S3xTest do
  use ExUnit.Case
  doctest S3x

  test "greets the world" do
    assert S3x.hello() == :world
  end
end
