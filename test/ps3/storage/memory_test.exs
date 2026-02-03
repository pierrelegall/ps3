defmodule PS3.Storage.MemoryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias PS3.Storage.Memory
  alias PS3.Storage.Memory.Sandbox

  setup do
    Memory.init()

    on_exit(fn -> Memory.clean_up() end)

    :ok
  end

  describe "initialization" do
    test "storage_root/0 returns `nil`" do
      assert Memory.storage_root() == nil
    end

    @tag :async_false
    test "init/0 creates ETS tables when sandbox is disabled" do
      # This test must run synchronously and temporarily disable sandbox
      original_mode = Application.get_env(:ps3, :ps3_sandbox_mode_setting)
      Application.delete_env(:ps3, :ps3_sandbox_mode_setting)

      # Clean up any existing tables
      if :ets.whereis(:ps3_buckets) != :undefined do
        :ets.delete(:ps3_buckets)
      end

      if :ets.whereis(:ps3_objects) != :undefined do
        :ets.delete(:ps3_objects)
      end

      # Now test that init creates the tables
      assert :ok = Memory.init()
      assert :ets.whereis(:ps3_buckets) != :undefined
      assert :ets.whereis(:ps3_objects) != :undefined

      # Clean up
      :ets.delete(:ps3_buckets)
      :ets.delete(:ps3_objects)

      # Restore original mode
      if original_mode do
        Sandbox.mode(original_mode)
      end
    end

    test "init/0 is idempotent" do
      # Calling init multiple times should not error
      assert :ok = Memory.init()
      assert :ok = Memory.init()
    end

    test "init/0 creates per-process tables in sandbox mode" do
      # In sandbox mode (default for tests), init creates per-process tables
      assert :ok = Memory.init()

      # Verify we can use the storage (tables exist for this process)
      assert {:ok, "test-bucket"} = Memory.create_bucket("test-bucket")
      {:ok, buckets} = Memory.list_buckets()
      assert length(buckets) == 1
    end

    test "clean_up/0 clears per-process tables in sandbox mode" do
      # Create some data
      Memory.create_bucket("bucket-1")
      Memory.create_bucket("bucket-2")
      Memory.put_object("bucket-1", "file.txt", "content")

      # Verify data exists
      {:ok, buckets} = Memory.list_buckets()
      assert length(buckets) == 2

      # Clean the storage
      assert :ok = Memory.clean_up()

      # Verify everything is cleared
      {:ok, buckets_after} = Memory.list_buckets()
      assert buckets_after == []
    end
  end

  describe "bucket operations" do
    test "create_bucket/1 creates a new bucket in memory" do
      assert {:ok, "test-bucket"} = Memory.create_bucket("test-bucket")

      # Verify bucket exists by listing it
      {:ok, buckets} = Memory.list_buckets()
      assert Enum.any?(buckets, fn b -> b.name == "test-bucket" end)
    end

    test "create_bucket/1 returns error if bucket already exists" do
      Memory.create_bucket("test-bucket")
      assert {:error, :bucket_already_exists} = Memory.create_bucket("test-bucket")
    end

    test "list_buckets/0 returns all buckets with metadata" do
      Memory.create_bucket("bucket-1")
      Memory.create_bucket("bucket-2")

      {:ok, buckets} = Memory.list_buckets()
      bucket_names = Enum.map(buckets, & &1.name)

      assert "bucket-1" in bucket_names
      assert "bucket-2" in bucket_names
      assert Enum.all?(buckets, &Map.has_key?(&1, :creation_date))
    end

    test "list_buckets/0 returns empty list when no buckets exist" do
      assert {:ok, []} = Memory.list_buckets()
    end

    test "delete_bucket/1 deletes an empty bucket from memory" do
      Memory.create_bucket("test-bucket")
      assert :ok = Memory.delete_bucket("test-bucket")

      # Verify bucket no longer exists by trying to list objects
      assert {:error, :no_such_bucket} = Memory.list_objects("test-bucket")
    end

    test "delete_bucket/1 returns error if bucket does not exist" do
      assert {:error, :no_such_bucket} = Memory.delete_bucket("nonexistent")
    end

    test "delete_bucket/1 returns error if bucket is not empty" do
      Memory.create_bucket("test-bucket")
      Memory.put_object("test-bucket", "file.txt", "content")
      assert {:error, :bucket_not_empty} = Memory.delete_bucket("test-bucket")
    end
  end

  describe "object operations" do
    setup do
      Memory.create_bucket("test-bucket")
      :ok
    end

    test "put_object/3 stores an object in memory" do
      assert {:ok, "file.txt"} = Memory.put_object("test-bucket", "file.txt", "hello world")

      # Verify object exists by retrieving it
      assert {:ok, "hello world"} = Memory.get_object("test-bucket", "file.txt")
    end

    test "put_object/3 handles keys with slashes" do
      assert {:ok, "dir/subdir/file.txt"} =
               Memory.put_object("test-bucket", "dir/subdir/file.txt", "nested content")

      assert {:ok, "nested content"} = Memory.get_object("test-bucket", "dir/subdir/file.txt")
    end

    test "put_object/3 returns error if bucket does not exist" do
      assert {:error, :no_such_bucket} = Memory.put_object("nonexistent", "file.txt", "content")
    end

    test "put_object/3 stores size and last_modified metadata" do
      Memory.put_object("test-bucket", "file.txt", "hello world")

      # Verify metadata via list_objects
      {:ok, objects} = Memory.list_objects("test-bucket")
      [object] = Enum.filter(objects, fn obj -> obj.key == "file.txt" end)

      size = object.size
      last_modified = object.last_modified

      assert size == 11
      assert %DateTime{} = last_modified
    end

    test "get_object/2 retrieves an object from memory" do
      Memory.put_object("test-bucket", "file.txt", "hello world")
      assert {:ok, "hello world"} = Memory.get_object("test-bucket", "file.txt")
    end

    test "get_object/2 returns error if object does not exist" do
      assert {:error, :no_such_key} = Memory.get_object("test-bucket", "nonexistent.txt")
    end

    test "delete_object/2 removes an object from memory" do
      Memory.put_object("test-bucket", "file.txt", "content")
      assert :ok = Memory.delete_object("test-bucket", "file.txt")

      # Verify object no longer exists
      assert {:error, :no_such_key} = Memory.get_object("test-bucket", "file.txt")
    end

    test "delete_object/2 returns error if object does not exist" do
      assert {:error, :no_such_key} = Memory.delete_object("test-bucket", "nonexistent.txt")
    end

    test "list_objects/1 returns all objects in a bucket with metadata" do
      Memory.put_object("test-bucket", "file1.txt", "content1")
      Memory.put_object("test-bucket", "file2.txt", "content2")
      Memory.put_object("test-bucket", "dir/file3.txt", "content3")

      {:ok, objects} = Memory.list_objects("test-bucket")
      keys = Enum.map(objects, & &1.key)

      assert "file1.txt" in keys
      assert "file2.txt" in keys
      assert "dir/file3.txt" in keys
      assert Enum.all?(objects, &Map.has_key?(&1, :size))
      assert Enum.all?(objects, &Map.has_key?(&1, :last_modified))
    end

    test "list_objects/1 returns empty list for empty bucket" do
      assert {:ok, []} = Memory.list_objects("test-bucket")
    end

    test "list_objects/1 returns error if bucket does not exist" do
      assert {:error, :no_such_bucket} = Memory.list_objects("nonexistent")
    end

    test "list_objects/1 does not include objects from other buckets" do
      Memory.create_bucket("other-bucket")
      Memory.put_object("test-bucket", "file1.txt", "content1")
      Memory.put_object("other-bucket", "file2.txt", "content2")

      {:ok, objects} = Memory.list_objects("test-bucket")
      keys = Enum.map(objects, & &1.key)

      assert "file1.txt" in keys
      refute "file2.txt" in keys
    end

    test "handles binary data correctly" do
      binary_data = <<1, 2, 3, 4, 5, 255, 254, 253>>
      assert {:ok, "binary.dat"} = Memory.put_object("test-bucket", "binary.dat", binary_data)
      assert {:ok, ^binary_data} = Memory.get_object("test-bucket", "binary.dat")
    end

    test "handles large data" do
      large_data = :crypto.strong_rand_bytes(1_000_000)
      assert {:ok, "large.bin"} = Memory.put_object("test-bucket", "large.bin", large_data)
      assert {:ok, ^large_data} = Memory.get_object("test-bucket", "large.bin")
    end

    test "overwrites existing objects" do
      Memory.put_object("test-bucket", "file.txt", "original")
      Memory.put_object("test-bucket", "file.txt", "updated")
      assert {:ok, "updated"} = Memory.get_object("test-bucket", "file.txt")

      # Should still only have one object with this key
      {:ok, objects} = Memory.list_objects("test-bucket")
      matching = Enum.filter(objects, &(&1.key == "file.txt"))
      assert length(matching) == 1
    end
  end
end
