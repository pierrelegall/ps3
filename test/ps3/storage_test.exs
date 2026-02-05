defmodule PS3.StorageTest do
  use ExUnit.Case, async: false

  @moduletag :unit
  @moduletag :storage

  alias PS3.Storage

  describe "backend/0" do
    test "defaults to Filesystem when no backend is configured" do
      Storage.reset_backend()
      assert Storage.backend() == PS3.Storage.Filesystem
    end

    test "returns Memory when configured" do
      Storage.backend(PS3.Storage.Memory)
      assert Storage.backend() == PS3.Storage.Memory
    end

    test "returns Filesystem when configured" do
      Storage.backend(PS3.Storage.Filesystem)
      assert Storage.backend() == PS3.Storage.Filesystem
    end
  end

  describe "backend/1" do
    test "accepts a module that implements PS3.Storage" do
      assert :ok = Storage.backend(PS3.Storage.Memory)
      assert Storage.backend() == PS3.Storage.Memory
    end

    test "rejects a module that does not implement PS3.Storage" do
      assert {:error, :invalid_backend} = Storage.backend(Regex)
      assert {:error, :invalid_backend} = Storage.backend(NotABackend)
    end
  end
end
