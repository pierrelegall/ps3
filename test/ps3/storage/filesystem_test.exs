defmodule PS3.Storage.FilesystemTest do
  use ExUnit.Case

  alias PS3.Storage.Filesystem

  setup do
    # Configure environment for filesystem backend
    System.put_env("PS3_STORAGE_ROOT", test_storage_root())
    File.rm_rf(test_storage_root())
    Filesystem.init()

    on_exit(fn ->
      File.rm_rf(test_storage_root())
    end)

    :ok
  end

  describe "initialization" do
    test "storage_root/0 returns configured root" do
      assert Filesystem.storage_root() == test_storage_root()
    end

    test "init/0 creates storage directory" do
      File.rm_rf(test_storage_root())
      Filesystem.init()
      assert File.exists?(test_storage_root())
    end
  end

  describe "bucket operations" do
    test "create_bucket/1 creates a new bucket directory" do
      assert {:ok, "test-bucket"} = Filesystem.create_bucket("test-bucket")
      assert File.exists?(Path.join(test_storage_root(), "test-bucket"))
    end

    test "create_bucket/1 returns error if bucket already exists" do
      Filesystem.create_bucket("test-bucket")
      assert {:error, :bucket_already_exists} = Filesystem.create_bucket("test-bucket")
    end

    test "list_buckets/0 returns all buckets with metadata" do
      Filesystem.create_bucket("bucket-1")
      Filesystem.create_bucket("bucket-2")

      {:ok, buckets} = Filesystem.list_buckets()
      bucket_names = Enum.map(buckets, & &1.name)

      assert "bucket-1" in bucket_names
      assert "bucket-2" in bucket_names
      assert Enum.all?(buckets, &Map.has_key?(&1, :creation_date))
    end

    test "delete_bucket/1 deletes an empty bucket" do
      Filesystem.create_bucket("test-bucket")
      assert :ok = Filesystem.delete_bucket("test-bucket")
      refute File.exists?(Path.join(test_storage_root(), "test-bucket"))
    end

    test "delete_bucket/1 returns error if bucket does not exist" do
      assert {:error, :no_such_bucket} = Filesystem.delete_bucket("nonexistent")
    end

    test "delete_bucket/1 returns error if bucket is not empty" do
      Filesystem.create_bucket("test-bucket")
      Filesystem.put_object("test-bucket", "file.txt", "content")
      assert {:error, :bucket_not_empty} = Filesystem.delete_bucket("test-bucket")
    end
  end

  describe "object operations" do
    setup do
      Filesystem.create_bucket("test-bucket")
      :ok
    end

    test "put_object/3 stores an object to filesystem" do
      assert {:ok, "file.txt"} = Filesystem.put_object("test-bucket", "file.txt", "hello world")

      path = Path.join([test_storage_root(), "test-bucket", "file.txt"])
      assert File.exists?(path)
      assert File.read!(path) == "hello world"
    end

    test "put_object/3 creates nested directories for keys with slashes" do
      assert {:ok, "dir/subdir/file.txt"} =
               Filesystem.put_object("test-bucket", "dir/subdir/file.txt", "nested content")

      path = Path.join([test_storage_root(), "test-bucket", "dir", "subdir", "file.txt"])
      assert File.exists?(path)
      assert File.read!(path) == "nested content"
    end

    test "put_object/3 returns error if bucket does not exist" do
      assert {:error, :no_such_bucket} =
               Filesystem.put_object("nonexistent", "file.txt", "content")
    end

    test "get_object/2 retrieves an object" do
      Filesystem.put_object("test-bucket", "file.txt", "hello world")
      assert {:ok, "hello world"} = Filesystem.get_object("test-bucket", "file.txt")
    end

    test "get_object/2 returns error if object does not exist" do
      assert {:error, :no_such_key} = Filesystem.get_object("test-bucket", "nonexistent.txt")
    end

    test "delete_object/2 removes an object from filesystem" do
      Filesystem.put_object("test-bucket", "file.txt", "content")
      assert :ok = Filesystem.delete_object("test-bucket", "file.txt")

      path = Path.join([test_storage_root(), "test-bucket", "file.txt"])
      refute File.exists?(path)
    end

    test "delete_object/2 returns error if object does not exist" do
      assert {:error, :no_such_key} = Filesystem.delete_object("test-bucket", "nonexistent.txt")
    end

    test "list_objects/1 returns all objects in a bucket with metadata" do
      Filesystem.put_object("test-bucket", "file1.txt", "content1")
      Filesystem.put_object("test-bucket", "file2.txt", "content2")
      Filesystem.put_object("test-bucket", "dir/file3.txt", "content3")

      {:ok, objects} = Filesystem.list_objects("test-bucket")
      keys = Enum.map(objects, & &1.key)

      assert "file1.txt" in keys
      assert "file2.txt" in keys
      assert "dir/file3.txt" in keys
      assert Enum.all?(objects, &Map.has_key?(&1, :size))
      assert Enum.all?(objects, &Map.has_key?(&1, :last_modified))
    end

    test "list_objects/1 returns error if bucket does not exist" do
      assert {:error, :no_such_bucket} = Filesystem.list_objects("nonexistent")
    end

    test "handles binary data correctly" do
      binary_data = <<1, 2, 3, 4, 5, 255, 254, 253>>
      assert {:ok, "binary.dat"} = Filesystem.put_object("test-bucket", "binary.dat", binary_data)
      assert {:ok, ^binary_data} = Filesystem.get_object("test-bucket", "binary.dat")
    end
  end

  defp test_storage_root do
    System.tmp_dir!()
    |> Path.join("ps3_test_data")
  end
end
