defmodule PS3.IntegrationTest do
  use ExUnit.Case, async: true

  alias PS3.Storage.Memory.Sandbox

  @test_bucket "test-bucket"
  @test_key "test-file.txt"
  @test_content "Hello, PS3!"

  setup do
    # Start an owner process for this test's sandbox
    pid = Sandbox.start_owner!()
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    # Encode owner PID for HTTP header
    owner = Sandbox.encode_metadata(pid)

    # Allow the current test process to use the sandbox too
    :ok = Sandbox.allow(pid, self())

    {:ok, sandbox_owner: owner}
  end

  # Helper to add sandbox header to ExAws requests
  # Note: ExAws doesn't support custom headers via request options,
  # they must be added to the operation struct directly
  defp with_sandbox(operation, owner) do
    headers = Map.put(operation.headers, "x-ps3-sandbox-owner", owner)

    %{operation | headers: headers}
    |> ExAws.request()
  end

  describe "PutObject" do
    setup %{sandbox_owner: owner} do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> with_sandbox(owner)

      :ok
    end

    test "stores an object successfully", %{sandbox_owner: owner} do
      assert {:ok, _response} =
               @test_bucket
               |> ExAws.S3.put_object(@test_key, @test_content)
               |> with_sandbox(owner)
    end

    test "stores binary content", %{sandbox_owner: owner} do
      binary_content = <<1, 2, 3, 4, 5>>

      assert {:ok, _response} =
               @test_bucket
               |> ExAws.S3.put_object("binary.bin", binary_content)
               |> with_sandbox(owner)
    end

    test "stores large content", %{sandbox_owner: owner} do
      large_content = String.duplicate("a", 10_000)

      assert {:ok, _response} =
               @test_bucket
               |> ExAws.S3.put_object("large.txt", large_content)
               |> with_sandbox(owner)
    end
  end

  describe "GetObject" do
    setup %{sandbox_owner: owner} do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> with_sandbox(owner)

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object(@test_key, @test_content)
        |> with_sandbox(owner)

      :ok
    end

    test "retrieves an object successfully", %{sandbox_owner: owner} do
      assert {:ok, %{body: body}} =
               @test_bucket
               |> ExAws.S3.get_object(@test_key)
               |> with_sandbox(owner)

      assert body == @test_content
    end

    test "returns error for non-existent object", %{sandbox_owner: owner} do
      assert {:error, {:http_error, 404, _}} =
               @test_bucket
               |> ExAws.S3.get_object("non-existent.txt")
               |> with_sandbox(owner)
    end
  end

  describe "DeleteObject" do
    setup %{sandbox_owner: owner} do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> with_sandbox(owner)

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object(@test_key, @test_content)
        |> with_sandbox(owner)

      :ok
    end

    test "deletes an object successfully", %{sandbox_owner: owner} do
      assert {:ok, _response} =
               @test_bucket
               |> ExAws.S3.delete_object(@test_key)
               |> with_sandbox(owner)

      # Verify object is gone
      assert {:error, {:http_error, 404, _}} =
               @test_bucket
               |> ExAws.S3.get_object(@test_key)
               |> with_sandbox(owner)
    end

    test "deleting non-existent object succeeds", %{sandbox_owner: owner} do
      assert {:ok, _response} =
               @test_bucket
               |> ExAws.S3.delete_object("non-existent.txt")
               |> with_sandbox(owner)
    end
  end

  describe "ListObjects" do
    setup %{sandbox_owner: owner} do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> with_sandbox(owner)

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object("file1.txt", "content1")
        |> with_sandbox(owner)

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object("file2.txt", "content2")
        |> with_sandbox(owner)

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object("dir/file3.txt", "content3")
        |> with_sandbox(owner)

      :ok
    end

    test "lists objects in bucket", %{sandbox_owner: owner} do
      assert {:ok, %{body: body}} =
               @test_bucket
               |> ExAws.S3.list_objects()
               |> with_sandbox(owner)

      assert Enum.count(body.contents) >= 3

      keys = Enum.map(body.contents, & &1.key)

      assert "file1.txt" in keys
      assert "file2.txt" in keys
      assert "dir/file3.txt" in keys
    end

    @tag :skip
    test "lists objects with prefix (not yet supported)", %{sandbox_owner: owner} do
      assert {:ok, %{body: body}} =
               @test_bucket
               |> ExAws.S3.list_objects(prefix: "dir/")
               |> with_sandbox(owner)

      refute Enum.empty?(body.contents)

      keys = Enum.map(body.contents, & &1.key)

      assert "dir/file3.txt" in keys
      refute "file1.txt" in keys
    end
  end

  describe "HeadObject (not yet supported)" do
    setup %{sandbox_owner: owner} do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> with_sandbox(owner)

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object(@test_key, @test_content)
        |> with_sandbox(owner)

      :ok
    end

    @tag :skip
    test "retrieves object metadata", %{sandbox_owner: owner} do
      assert {:ok, %{headers: headers}} =
               @test_bucket
               |> ExAws.S3.head_object(@test_key)
               |> with_sandbox(owner)

      content_length =
        headers
        |> Enum.find(fn {k, _v} -> String.downcase(k) == "content-length" end)
        |> elem(1)

      assert String.to_integer(content_length) == byte_size(@test_content)
    end

    @tag :skip
    test "returns error for non-existent object", %{sandbox_owner: owner} do
      assert {:error, {:http_error, 404, _}} =
               @test_bucket
               |> ExAws.S3.head_object("non-existent.txt")
               |> with_sandbox(owner)
    end
  end

  describe "concurrent operations" do
    setup %{sandbox_owner: owner} do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> with_sandbox(owner)

      :ok
    end

    test "handles concurrent put operations", %{sandbox_owner: owner} do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            @test_bucket
            |> ExAws.S3.put_object("concurrent-#{i}.txt", "content-#{i}")
            |> with_sandbox(owner)
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, fn {status, _} -> status == :ok end)
    end

    test "handles concurrent read operations", %{sandbox_owner: owner} do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object("shared.txt", "shared")
        |> with_sandbox(owner)

      tasks =
        for _i <- 1..10 do
          Task.async(fn ->
            ExAws.S3.get_object(@test_bucket, "shared.txt")
            |> with_sandbox(owner)
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, fn {status, _} -> status == :ok end)
    end
  end
end
