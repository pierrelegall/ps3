defmodule PS3.IntegrationTest do
  use ExUnit.Case, async: true

  @test_bucket "test-bucket"
  @test_key "test-file.txt"
  @test_content "Hello, PS3!"

  describe "PutObject" do
    setup do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> ExAws.request()

      :ok
    end

    test "stores an object successfully" do
      assert {:ok, _response} =
               @test_bucket
               |> ExAws.S3.put_object(@test_key, @test_content)
               |> ExAws.request()
    end

    test "stores binary content" do
      binary_content = <<1, 2, 3, 4, 5>>

      assert {:ok, _response} =
               @test_bucket
               |> ExAws.S3.put_object("binary.bin", binary_content)
               |> ExAws.request()
    end

    test "stores large content" do
      large_content = String.duplicate("a", 10_000)

      assert {:ok, _response} =
               @test_bucket
               |> ExAws.S3.put_object("large.txt", large_content)
               |> ExAws.request()
    end
  end

  describe "GetObject" do
    setup do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> ExAws.request()

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object(@test_key, @test_content)
        |> ExAws.request()

      :ok
    end

    test "retrieves an object successfully" do
      assert {:ok, %{body: body}} =
               @test_bucket
               |> ExAws.S3.get_object(@test_key)
               |> ExAws.request()

      assert body == @test_content
    end

    test "returns error for non-existent object" do
      assert {:error, {:http_error, 404, _}} =
               @test_bucket
               |> ExAws.S3.get_object("non-existent.txt")
               |> ExAws.request()
    end
  end

  describe "DeleteObject" do
    setup do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> ExAws.request()

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object(@test_key, @test_content)
        |> ExAws.request()

      :ok
    end

    test "deletes an object successfully" do
      assert {:ok, _response} =
               @test_bucket
               |> ExAws.S3.delete_object(@test_key)
               |> ExAws.request()

      # Verify object is gone
      assert {:error, {:http_error, 404, _}} =
               @test_bucket
               |> ExAws.S3.get_object(@test_key)
               |> ExAws.request()
    end

    test "deleting non-existent object succeeds" do
      assert {:ok, _response} =
               @test_bucket
               |> ExAws.S3.delete_object("non-existent.txt")
               |> ExAws.request()
    end
  end

  describe "ListObjects" do
    setup do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> ExAws.request()

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object("file1.txt", "content1")
        |> ExAws.request()

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object("file2.txt", "content2")
        |> ExAws.request()

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object("dir/file3.txt", "content3")
        |> ExAws.request()

      :ok
    end

    test "lists objects in bucket" do
      assert {:ok, %{body: body}} =
               @test_bucket
               |> ExAws.S3.list_objects()
               |> ExAws.request()

      assert Enum.count(body.contents) >= 3

      keys = Enum.map(body.contents, & &1.key)

      assert "file1.txt" in keys
      assert "file2.txt" in keys
      assert "dir/file3.txt" in keys
    end

    @tag :skip
    test "lists objects with prefix (not yet supported)" do
      assert {:ok, %{body: body}} =
               @test_bucket
               |> ExAws.S3.list_objects(prefix: "dir/")
               |> ExAws.request()

      refute Enum.empty?(body.contents)

      keys = Enum.map(body.contents, & &1.key)

      assert "dir/file3.txt" in keys
      refute "file1.txt" in keys
    end
  end

  describe "HeadObject (not yet supported)" do
    setup do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> ExAws.request()

      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object(@test_key, @test_content)
        |> ExAws.request()

      :ok
    end

    @tag :skip
    test "retrieves object metadata" do
      assert {:ok, %{headers: headers}} =
               @test_bucket
               |> ExAws.S3.head_object(@test_key)
               |> ExAws.request()

      content_length =
        headers
        |> Enum.find(fn {k, _v} -> String.downcase(k) == "content-length" end)
        |> elem(1)

      assert String.to_integer(content_length) == byte_size(@test_content)
    end

    @tag :skip
    test "returns error for non-existent object" do
      assert {:error, {:http_error, 404, _}} =
               @test_bucket
               |> ExAws.S3.head_object("non-existent.txt")
               |> ExAws.request()
    end
  end

  describe "concurrent operations" do
    setup do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_bucket("local")
        |> ExAws.request()

      :ok
    end

    test "handles concurrent put operations" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            @test_bucket
            |> ExAws.S3.put_object("concurrent-#{i}.txt", "content-#{i}")
            |> ExAws.request()
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, fn {status, _} -> status == :ok end)
    end

    test "handles concurrent read operations" do
      {:ok, _} =
        @test_bucket
        |> ExAws.S3.put_object("shared.txt", "shared")
        |> ExAws.request()

      tasks =
        for _i <- 1..10 do
          Task.async(fn ->
            ExAws.S3.get_object(@test_bucket, "shared.txt")
            |> ExAws.request()
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, fn {status, _} -> status == :ok end)
    end
  end
end
