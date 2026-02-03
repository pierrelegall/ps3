defmodule PS3.StorageTest do
  use ExUnit.Case

  @moduletag :unit

  alias PS3.Storage

  @test_storage_root "./test_ps3_data"

  setup do
    # This test explicitly uses Filesystem backend (not Memory/Sandbox)
    Application.put_env(:ps3, :storage_backend, PS3.Storage.Filesystem)

    System.put_env("PS3_STORAGE_ROOT", @test_storage_root)
    File.rm_rf(@test_storage_root)
    Storage.init()

    on_exit(fn ->
      File.rm_rf(@test_storage_root)
      # Restore Memory backend for other tests
      Application.put_env(:ps3, :storage_backend, PS3.Storage.Memory)
    end)

    :ok
  end

  describe "bucket operations" do
    test "create_bucket/1 creates a new bucket" do
      assert {:ok, "test-bucket"} = Storage.create_bucket("test-bucket")
      assert File.exists?(Path.join(@test_storage_root, "test-bucket"))
    end

    test "create_bucket/1 returns error if bucket already exists" do
      Storage.create_bucket("test-bucket")
      assert {:error, :bucket_already_exists} = Storage.create_bucket("test-bucket")
    end

    test "list_buckets/0 returns all buckets" do
      Storage.create_bucket("bucket-1")
      Storage.create_bucket("bucket-2")

      {:ok, buckets} = Storage.list_buckets()
      bucket_names = Enum.map(buckets, & &1.name)

      assert "bucket-1" in bucket_names
      assert "bucket-2" in bucket_names
    end

    test "delete_bucket/1 deletes an empty bucket" do
      Storage.create_bucket("test-bucket")
      assert :ok = Storage.delete_bucket("test-bucket")
      refute File.exists?(Path.join(@test_storage_root, "test-bucket"))
    end

    test "delete_bucket/1 returns error if bucket does not exist" do
      assert {:error, :no_such_bucket} = Storage.delete_bucket("nonexistent")
    end

    test "delete_bucket/1 returns error if bucket is not empty" do
      Storage.create_bucket("test-bucket")
      Storage.put_object("test-bucket", "file.txt", "content")
      assert {:error, :bucket_not_empty} = Storage.delete_bucket("test-bucket")
    end
  end

  describe "object operations" do
    setup do
      Storage.create_bucket("test-bucket")
      :ok
    end

    test "put_object/3 stores an object" do
      assert {:ok, "file.txt"} = Storage.put_object("test-bucket", "file.txt", "hello world")

      path = Path.join([@test_storage_root, "test-bucket", "file.txt"])
      assert File.exists?(path)
      assert File.read!(path) == "hello world"
    end

    test "put_object/3 creates nested directories for keys with slashes" do
      assert {:ok, "dir/subdir/file.txt"} =
               Storage.put_object("test-bucket", "dir/subdir/file.txt", "nested content")

      path = Path.join([@test_storage_root, "test-bucket", "dir", "subdir", "file.txt"])
      assert File.exists?(path)
    end

    test "put_object/3 returns error if bucket does not exist" do
      assert {:error, :no_such_bucket} =
               Storage.put_object("nonexistent", "file.txt", "content")
    end

    test "get_object/2 retrieves an object" do
      Storage.put_object("test-bucket", "file.txt", "hello world")
      assert {:ok, "hello world"} = Storage.get_object("test-bucket", "file.txt")
    end

    test "get_object/2 returns error if object does not exist" do
      assert {:error, :no_such_key} = Storage.get_object("test-bucket", "nonexistent.txt")
    end

    test "delete_object/2 removes an object" do
      Storage.put_object("test-bucket", "file.txt", "content")
      assert :ok = Storage.delete_object("test-bucket", "file.txt")

      path = Path.join([@test_storage_root, "test-bucket", "file.txt"])
      refute File.exists?(path)
    end

    test "delete_object/2 returns error if object does not exist" do
      assert {:error, :no_such_key} = Storage.delete_object("test-bucket", "nonexistent.txt")
    end

    test "list_objects/1 returns all objects in a bucket" do
      Storage.put_object("test-bucket", "file1.txt", "content1")
      Storage.put_object("test-bucket", "file2.txt", "content2")
      Storage.put_object("test-bucket", "dir/file3.txt", "content3")

      {:ok, objects} = Storage.list_objects("test-bucket")
      keys = Enum.map(objects, & &1.key)

      assert "file1.txt" in keys
      assert "file2.txt" in keys
      assert "dir/file3.txt" in keys
    end

    test "list_objects/1 returns error if bucket does not exist" do
      assert {:error, :no_such_bucket} = Storage.list_objects("nonexistent")
    end
  end
end
