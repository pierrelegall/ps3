defmodule PS3.IntegrationCase do
  use ExUnit.CaseTemplate

  using opts do
    backend = Keyword.fetch!(opts, :backend)
    sandbox = Keyword.fetch!(opts, :sandbox)
    async = Keyword.get(opts, :async, false)

    quote do
      use ExUnit.Case, async: unquote(async), group: :integration

      @moduletag :integration
      @moduletag :api

      setup do
        PS3.IntegrationCase.setup_backend(unquote(backend), unquote(sandbox))
      end

      describe "PutObject" do
        test "stores an object successfully" do
          assert {:ok, _response} =
                   "test-bucket"
                   |> ExAws.S3.put_object("test-file.txt", "Hello, PS3!")
                   |> ExAws.request()
        end

        test "stores binary content" do
          binary_content = <<1, 2, 3, 4, 5>>

          assert {:ok, _response} =
                   "test-bucket"
                   |> ExAws.S3.put_object("binary.bin", binary_content)
                   |> ExAws.request()
        end

        test "stores large content" do
          large_content = String.duplicate("a", 10_000)

          assert {:ok, _response} =
                   "test-bucket"
                   |> ExAws.S3.put_object("large.txt", large_content)
                   |> ExAws.request()
        end
      end

      describe "GetObject" do
        setup do
          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("test-file.txt", "Hello, PS3!")
            |> ExAws.request()

          :ok
        end

        test "retrieves an object successfully" do
          assert {:ok, %{body: body}} =
                   "test-bucket"
                   |> ExAws.S3.get_object("test-file.txt")
                   |> ExAws.request()

          assert body == "Hello, PS3!"
        end

        test "returns error for non-existent object" do
          assert {:error, {:http_error, 404, _}} =
                   "test-bucket"
                   |> ExAws.S3.get_object("non-existent.txt")
                   |> ExAws.request()
        end
      end

      describe "DeleteObject" do
        setup do
          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("test-file.txt", "Hello, PS3!")
            |> ExAws.request()

          :ok
        end

        test "deletes an object successfully" do
          assert {:ok, _response} =
                   "test-bucket"
                   |> ExAws.S3.delete_object("test-file.txt")
                   |> ExAws.request()

          # Verify object is gone
          assert {:error, {:http_error, 404, _}} =
                   "test-bucket"
                   |> ExAws.S3.get_object("test-file.txt")
                   |> ExAws.request()
        end

        test "deleting non-existent object succeeds" do
          assert {:ok, _response} =
                   "test-bucket"
                   |> ExAws.S3.delete_object("non-existent.txt")
                   |> ExAws.request()
        end
      end

      describe "ListObjects" do
        setup do
          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("file1.txt", "content1")
            |> ExAws.request()

          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("file2.txt", "content2")
            |> ExAws.request()

          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("dir/file3.txt", "content3")
            |> ExAws.request()

          :ok
        end

        test "lists objects in bucket" do
          assert {:ok, %{body: body}} =
                   "test-bucket"
                   |> ExAws.S3.list_objects()
                   |> ExAws.request()

          assert Enum.count(body.contents) >= 3

          keys = Enum.map(body.contents, & &1.key)

          assert "file1.txt" in keys
          assert "file2.txt" in keys
          assert "dir/file3.txt" in keys
        end

        test "lists objects with prefix" do
          assert {:ok, %{body: body}} =
                   "test-bucket"
                   |> ExAws.S3.list_objects(prefix: "dir/")
                   |> ExAws.request()

          refute Enum.empty?(body.contents)

          keys = Enum.map(body.contents, & &1.key)

          assert "dir/file3.txt" in keys
          refute "file1.txt" in keys
        end

        test "lists objects with empty prefix returns all" do
          assert {:ok, %{body: body}} =
                   "test-bucket"
                   |> ExAws.S3.list_objects(prefix: "")
                   |> ExAws.request()

          keys = Enum.map(body.contents, & &1.key)

          assert "file1.txt" in keys
          assert "file2.txt" in keys
          assert "dir/file3.txt" in keys
        end

        test "lists objects with prefix matching no objects" do
          assert {:ok, %{body: body}} =
                   "test-bucket"
                   |> ExAws.S3.list_objects(prefix: "nonexistent/")
                   |> ExAws.request()

          assert Enum.empty?(body.contents)
        end
      end

      describe "HeadObject" do
        setup do
          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("test-file.txt", "Hello, PS3!")
            |> ExAws.request()

          :ok
        end

        test "retrieves object metadata" do
          assert {:ok, %{headers: headers}} =
                   "test-bucket"
                   |> ExAws.S3.head_object("test-file.txt")
                   |> ExAws.request()

          content_length =
            headers
            |> Enum.find(fn {k, _v} -> String.downcase(k) == "content-length" end)
            |> elem(1)

          assert String.to_integer(content_length) == byte_size("Hello, PS3!")
        end

        test "returns error for non-existent object" do
          assert {:error, {:http_error, 404, _}} =
                   "test-bucket"
                   |> ExAws.S3.head_object("non-existent.txt")
                   |> ExAws.request()
        end

        test "returns correct content-length" do
          content = "exact length test"

          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("length-test.txt", content)
            |> ExAws.request()

          assert {:ok, %{headers: headers}} =
                   "test-bucket"
                   |> ExAws.S3.head_object("length-test.txt")
                   |> ExAws.request()

          content_length =
            headers
            |> Enum.find(fn {k, _v} -> String.downcase(k) == "content-length" end)
            |> elem(1)

          assert String.to_integer(content_length) == byte_size(content)
        end

        test "returns empty body" do
          assert {:ok, %{body: body}} =
                   "test-bucket"
                   |> ExAws.S3.head_object("test-file.txt")
                   |> ExAws.request()

          assert body == ""
        end
      end

      describe "HeadBucket" do
        test "returns 200 for existing bucket" do
          assert {:ok, %{status_code: 200}} =
                   "test-bucket"
                   |> ExAws.S3.head_bucket()
                   |> ExAws.request()
        end

        test "returns 404 for non-existent bucket" do
          assert {:error, {:http_error, 404, _}} =
                   "no-such-bucket"
                   |> ExAws.S3.head_bucket()
                   |> ExAws.request()
        end
      end

      describe "ListObjectsV2" do
        setup do
          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("file1.txt", "content1")
            |> ExAws.request()

          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("file2.txt", "content2")
            |> ExAws.request()

          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("dir/file3.txt", "content3")
            |> ExAws.request()

          :ok
        end

        test "lists objects with list_objects_v2" do
          assert {:ok, %{body: body}} =
                   "test-bucket"
                   |> ExAws.S3.list_objects_v2()
                   |> ExAws.request()

          keys = Enum.map(body.contents, & &1.key)

          assert "file1.txt" in keys
          assert "file2.txt" in keys
          assert "dir/file3.txt" in keys
        end

        test "lists objects with prefix using v2" do
          assert {:ok, %{body: body}} =
                   "test-bucket"
                   |> ExAws.S3.list_objects_v2(prefix: "dir/")
                   |> ExAws.request()

          keys = Enum.map(body.contents, & &1.key)

          assert "dir/file3.txt" in keys
          refute "file1.txt" in keys
        end

        test "returns key_count in v2 response" do
          assert {:ok, %{body: body}} =
                   "test-bucket"
                   |> ExAws.S3.list_objects_v2(prefix: "dir/")
                   |> ExAws.request()

          assert body.key_count == "1"
        end
      end

      describe "CopyObject" do
        setup do
          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("test-file.txt", "Hello, PS3!")
            |> ExAws.request()

          :ok
        end

        test "copies an object to a new key" do
          assert {:ok, _} =
                   ExAws.S3.put_object_copy(
                     "test-bucket",
                     "copied.txt",
                     "test-bucket",
                     "test-file.txt"
                   )
                   |> ExAws.request()

          assert {:ok, %{body: body}} =
                   "test-bucket"
                   |> ExAws.S3.get_object("copied.txt")
                   |> ExAws.request()

          assert body == "Hello, PS3!"
        end

        test "copies an object to a different bucket" do
          {:ok, _} =
            "other-bucket"
            |> ExAws.S3.put_bucket("local")
            |> ExAws.request()

          assert {:ok, _} =
                   ExAws.S3.put_object_copy(
                     "other-bucket",
                     "copied.txt",
                     "test-bucket",
                     "test-file.txt"
                   )
                   |> ExAws.request()

          assert {:ok, %{body: body}} =
                   "other-bucket"
                   |> ExAws.S3.get_object("copied.txt")
                   |> ExAws.request()

          assert body == "Hello, PS3!"
        end

        test "returns error when source does not exist" do
          assert {:error, {:http_error, 404, _}} =
                   ExAws.S3.put_object_copy(
                     "test-bucket",
                     "dest.txt",
                     "test-bucket",
                     "no-such-key"
                   )
                   |> ExAws.request()
        end
      end

      describe "DeleteObjects" do
        setup do
          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("del1.txt", "content1")
            |> ExAws.request()

          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("del2.txt", "content2")
            |> ExAws.request()

          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("keep.txt", "content3")
            |> ExAws.request()

          :ok
        end

        test "deletes multiple objects" do
          assert {:ok, _} =
                   "test-bucket"
                   |> ExAws.S3.delete_multiple_objects(["del1.txt", "del2.txt"])
                   |> ExAws.request()

          assert {:error, {:http_error, 404, _}} =
                   "test-bucket"
                   |> ExAws.S3.get_object("del1.txt")
                   |> ExAws.request()

          assert {:error, {:http_error, 404, _}} =
                   "test-bucket"
                   |> ExAws.S3.get_object("del2.txt")
                   |> ExAws.request()

          # Untouched object still exists
          assert {:ok, %{body: "content3"}} =
                   "test-bucket"
                   |> ExAws.S3.get_object("keep.txt")
                   |> ExAws.request()
        end

        test "deletes with non-existent keys succeeds" do
          assert {:ok, _} =
                   "test-bucket"
                   |> ExAws.S3.delete_multiple_objects(["no-such-1.txt", "no-such-2.txt"])
                   |> ExAws.request()
        end
      end

      describe "concurrent operations" do
        test "handles concurrent put operations" do
          tasks =
            for i <- 1..10 do
              Task.async(fn ->
                "test-bucket"
                |> ExAws.S3.put_object("concurrent-#{i}.txt", "content-#{i}")
                |> ExAws.request()
              end)
            end

          results = Task.await_many(tasks)
          assert Enum.all?(results, fn {status, _} -> status == :ok end)
        end

        test "handles concurrent read operations" do
          {:ok, _} =
            "test-bucket"
            |> ExAws.S3.put_object("shared.txt", "shared")
            |> ExAws.request()

          tasks =
            for _i <- 1..10 do
              Task.async(fn ->
                ExAws.S3.get_object("test-bucket", "shared.txt")
                |> ExAws.request()
              end)
            end

          results = Task.await_many(tasks)
          assert Enum.all?(results, fn {status, _} -> status == :ok end)
        end
      end
    end
  end

  @doc false
  def setup_backend(:memory, sandbox) do
    set_sandbox(sandbox)
    PS3.Storage.init()

    {:ok, _} =
      "test-bucket"
      |> ExAws.S3.put_bucket("local")
      |> ExAws.request()

    :ok
  end

  def setup_backend(:filesystem, sandbox) do
    tmp_dir = Path.join(System.tmp_dir!(), "ps3_test_#{System.unique_integer([:positive])}")
    PS3.Storage.Filesystem.storage_root(tmp_dir)
    PS3.Storage.backend(PS3.Storage.Filesystem)
    set_sandbox(sandbox)
    PS3.Storage.init()

    {:ok, _} =
      "test-bucket"
      |> ExAws.S3.put_bucket("local")
      |> ExAws.request()

    :ok
  end

  defp set_sandbox(nil) do
    PS3.Storage.Memory.Sandbox.reset_mode()
  end

  defp set_sandbox(:shared) do
    pid = PS3.Storage.Memory.Sandbox.start_owner!(shared: true)
    ExUnit.Callbacks.on_exit(fn -> PS3.Storage.Memory.Sandbox.stop_owner(pid) end)
  end

  defp set_sandbox(:manual) do
    PS3.Storage.Memory.Sandbox.mode(:manual)
    PS3.Storage.Memory.Sandbox.checkout()
  end

  defp set_sandbox(:auto) do
    PS3.Storage.Memory.Sandbox.mode(:auto)
  end
end

defmodule PS3.Integration.MemoryAutoSandboxingTest do
  use PS3.IntegrationCase,
    backend: :memory,
    sandbox: :auto,
    async: true
end

defmodule PS3.Integration.MemoryManualSandboxingS3ApiTest do
  use PS3.IntegrationCase,
    backend: :memory,
    sandbox: :manual,
    async: true
end

defmodule PS3.Integration.MemorySharedSandboxingS3ApiTest do
  use PS3.IntegrationCase,
    backend: :memory,
    sandbox: :shared,
    async: false
end

defmodule PS3.Integration.FilesystemS3ApiTest do
  use PS3.IntegrationCase,
    backend: :filesystem,
    sandbox: nil,
    async: false
end
