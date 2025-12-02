defmodule S3x.Storage.MemoryTest do
  use ExUnit.Case
  alias S3x.Storage.Memory

  setup do
    # Initialize ETS tables for each test
    Memory.init()

    on_exit(fn ->
      # Clean up ETS tables after each test
      # Only delete if tables still exist
      if :ets.whereis(:s3x_buckets) != :undefined do
        :ets.delete_all_objects(:s3x_buckets)
      end

      if :ets.whereis(:s3x_objects) != :undefined do
        :ets.delete_all_objects(:s3x_objects)
      end
    end)

    :ok
  end

  describe "initialization" do
    test "storage_root/0 returns :memory: indicator" do
      assert Memory.storage_root() == ":memory:"
    end

    test "init/0 creates ETS tables" do
      # Tables should exist after init
      assert :ets.whereis(:s3x_buckets) != :undefined
      assert :ets.whereis(:s3x_objects) != :undefined
    end

    test "init/0 is idempotent" do
      # Calling init multiple times should not error
      assert :ok = Memory.init()
      assert :ok = Memory.init()
    end
  end

  describe "bucket operations" do
    test "create_bucket/1 creates a new bucket in memory" do
      assert {:ok, "test-bucket"} = Memory.create_bucket("test-bucket")

      # Verify bucket exists in ETS
      assert [{_name, _creation_date}] = :ets.lookup(:s3x_buckets, "test-bucket")
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

      # Verify bucket no longer exists in ETS
      assert [] = :ets.lookup(:s3x_buckets, "test-bucket")
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

      # Verify object exists in ETS
      assert [{{_bucket, _key}, data, _size, _modified}] =
               :ets.lookup(:s3x_objects, {"test-bucket", "file.txt"})

      assert data == "hello world"
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

      [{{_bucket, _key}, _data, size, last_modified}] =
        :ets.lookup(:s3x_objects, {"test-bucket", "file.txt"})

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

      # Verify object no longer exists in ETS
      assert [] = :ets.lookup(:s3x_objects, {"test-bucket", "file.txt"})
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

  describe "performance characteristics" do
    test "handles many buckets efficiently" do
      # Create 1000 buckets
      for i <- 1..1000 do
        assert {:ok, _} = Memory.create_bucket("bucket-#{i}")
      end

      {:ok, buckets} = Memory.list_buckets()
      assert length(buckets) == 1000
    end

    test "handles many objects per bucket efficiently" do
      Memory.create_bucket("test-bucket")

      # Create 1000 objects
      for i <- 1..1000 do
        assert {:ok, _} = Memory.put_object("test-bucket", "file-#{i}.txt", "content")
      end

      {:ok, objects} = Memory.list_objects("test-bucket")
      assert length(objects) == 1000
    end
  end
end
