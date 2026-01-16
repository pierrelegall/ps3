defmodule PS3.ConcurrentTest do
  use ExUnit.Case, async: true

  alias PS3.Storage

  test "test A: creates bucket and expects it empty" do
    bucket = "bucket-a-#{System.unique_integer([:positive])}"

    assert {:ok, ^bucket} = Storage.create_bucket(bucket)

    # Simulate some work
    Process.sleep(5)

    # Should be empty, but might find objects from other concurrent tests
    # if they happen to use overlapping bucket names or if state bleeds
    {:ok, objects} = Storage.list_objects(bucket)

    assert Enum.empty?(objects),
           "Expected bucket #{bucket} to be empty, found: #{inspect(objects)}"
  end

  test "test B: creates bucket with one object" do
    bucket = "bucket-b-#{System.unique_integer([:positive])}"

    assert {:ok, ^bucket} = Storage.create_bucket(bucket)
    assert {:ok, "file.txt"} = Storage.put_object(bucket, "file.txt", "data")

    # Simulate some work
    Process.sleep(5)

    # Should have exactly one object
    {:ok, objects} = Storage.list_objects(bucket)

    assert length(objects) == 1,
           "Expected bucket #{bucket} to have 1 object, found #{length(objects)}: #{inspect(objects)}"
  end

  test "test C: creates bucket with multiple objects" do
    bucket = "bucket-c-#{System.unique_integer([:positive])}"

    assert {:ok, ^bucket} = Storage.create_bucket(bucket)
    assert {:ok, "file1.txt"} = Storage.put_object(bucket, "file1.txt", "data1")
    assert {:ok, "file2.txt"} = Storage.put_object(bucket, "file2.txt", "data2")
    assert {:ok, "file3.txt"} = Storage.put_object(bucket, "file3.txt", "data3")

    # Simulate some work
    Process.sleep(5)

    # Should have exactly three objects
    {:ok, objects} = Storage.list_objects(bucket)

    assert length(objects) == 3,
           "Expected bucket #{bucket} to have 3 objects, found #{length(objects)}: #{inspect(objects)}"
  end

  test "test D: deletes bucket after creating it" do
    bucket = "bucket-d-#{System.unique_integer([:positive])}"

    assert {:ok, ^bucket} = Storage.create_bucket(bucket)

    # Simulate some work
    Process.sleep(5)

    assert :ok = Storage.delete_bucket(bucket)

    # Should not exist anymore
    assert {:error, :no_such_bucket} = Storage.list_objects(bucket)
  end

  test "test E: sees ONLY its own buckets (sandbox isolation works!)" do
    # Create some buckets for this test
    bucket1 = "bucket-e1-#{System.unique_integer([:positive])}"
    bucket2 = "bucket-e2-#{System.unique_integer([:positive])}"

    assert {:ok, ^bucket1} = Storage.create_bucket(bucket1)
    assert {:ok, ^bucket2} = Storage.create_bucket(bucket2)

    # Simulate some work
    Process.sleep(5)

    # List all buckets - should ONLY see this test's buckets thanks to sandbox!
    {:ok, all_buckets} = Storage.list_buckets()
    bucket_names = Enum.map(all_buckets, & &1.name)

    # These assertions PASS, showing our buckets exist
    assert bucket1 in bucket_names
    assert bucket2 in bucket_names

    # This assertion now PASSES: we only see OUR buckets!
    # Sandbox provides perfect isolation - each test has its own storage
    assert length(all_buckets) == 2,
           """
           Expected to see only 2 buckets (this test's buckets),
           but saw #{length(all_buckets)} buckets: #{inspect(bucket_names)}
           """
  end
end
