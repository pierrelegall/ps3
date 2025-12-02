defmodule S3xTest do
  use ExUnit.Case
  doctest S3x

  test "module exists" do
    assert Code.ensure_loaded?(S3x)
  end
end
