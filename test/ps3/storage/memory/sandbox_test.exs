defmodule PS3.Storage.Memory.SandboxTest do
  # async: false because these tests modify global sandbox mode
  use ExUnit.Case, async: false

  @moduletag :unit

  alias PS3.Storage.Memory.Sandbox

  setup do
    Sandbox.mode(:auto)
  end

  describe "checkout/1" do
    test "successfully checks out sandbox for current process" do
      assert :ok = Sandbox.checkout()
    end

    test "returns {:already, :owner} when process already owns sandbox" do
      assert :ok = Sandbox.checkout()
      assert {:already, :owner} = Sandbox.checkout()
    end

    test "returns {:already, :allowed} when process is allowed by another owner" do
      owner = spawn_owner()

      :ok = Sandbox.allow(owner, self())
      assert {:already, :allowed} = Sandbox.checkout()

      Sandbox.stop_owner(owner)
    end
  end

  describe "checkin/0" do
    test "releases ownership and cleans up" do
      assert :ok = Sandbox.checkout()
      assert :ok = Sandbox.checkin()

      # After checkin, we can checkout again
      assert :ok = Sandbox.checkout()
    end

    test "removes allowances for the owner" do
      owner = Sandbox.start_owner!()
      child = spawn(fn -> Process.sleep(:infinity) end)

      :ok = Sandbox.allow(owner, child)

      # Child should be able to find tables via owner
      assert {:ok, _} = Sandbox.find_tables(child)

      # Stop owner (which calls checkin)
      Sandbox.stop_owner(owner)

      # Child should no longer have access
      assert :not_found = Sandbox.find_tables(child)

      Process.exit(child, :kill)
    end
  end

  describe "allow/3" do
    test "successfully allows a process to use owner's sandbox" do
      owner = Sandbox.start_owner!()
      child = spawn(fn -> Process.sleep(:infinity) end)

      assert :ok = Sandbox.allow(owner, child)

      # Verify child can access owner's tables
      assert {:ok, tables} = Sandbox.find_tables(owner)
      assert {:ok, ^tables} = Sandbox.find_tables(child)

      Sandbox.stop_owner(owner)
      Process.exit(child, :kill)
    end

    test "returns :not_found when parent is not an owner" do
      child = spawn(fn -> Process.sleep(:infinity) end)
      fake_owner = spawn(fn -> Process.sleep(:infinity) end)

      assert :not_found = Sandbox.allow(fake_owner, child)

      Process.exit(child, :kill)
      Process.exit(fake_owner, :kill)
    end

    test "returns {:already, :owner} when child is already an owner" do
      owner = Sandbox.start_owner!()

      # Current process also checks out (becomes owner)
      assert :ok = Sandbox.checkout()

      # Try to allow current process under another owner
      assert {:already, :owner} = Sandbox.allow(owner, self())

      Sandbox.stop_owner(owner)
    end

    test "returns {:already, :allowed} when child is already allowed" do
      owner = Sandbox.start_owner!()
      child = spawn(fn -> Process.sleep(:infinity) end)

      assert :ok = Sandbox.allow(owner, child)
      assert {:already, :allowed} = Sandbox.allow(owner, child)

      Sandbox.stop_owner(owner)
      Process.exit(child, :kill)
    end
  end

  describe "mode/1" do
    test "sets mode: auto" do
      assert :ok = Sandbox.mode(:auto)
    end

    test "sets mode: manual" do
      assert :ok = Sandbox.mode(:manual)
    end

    test "sets shared mode with valid owner" do
      owner = Sandbox.start_owner!()
      assert :ok = Sandbox.mode({:shared, owner})
      Sandbox.stop_owner(owner)
    end

    test "returns :already_shared when already in shared mode with same pid" do
      owner = Sandbox.start_owner!()
      assert :ok = Sandbox.mode({:shared, owner})
      assert :already_shared = Sandbox.mode({:shared, owner})
      Sandbox.stop_owner(owner)
    end

    test "returns :not_found when shared pid is not in registry" do
      fake_pid = spawn(fn -> Process.sleep(:infinity) end)
      assert :not_found = Sandbox.mode({:shared, fake_pid})
      Process.exit(fake_pid, :kill)
    end

    test "returns :not_owner when shared pid is allowed but not owner" do
      owner = Sandbox.start_owner!()
      allowed = spawn(fn -> Process.sleep(:infinity) end)
      Sandbox.allow(owner, allowed)

      assert :not_owner = Sandbox.mode({:shared, allowed})

      Sandbox.stop_owner(owner)
      Process.exit(allowed, :kill)
    end
  end

  describe "start_owner!/1 and stop_owner/1" do
    test "spawns a linked owner process" do
      pid = Sandbox.start_owner!()
      assert is_pid(pid)
      assert Process.alive?(pid)
      Sandbox.stop_owner(pid)
    end

    test "owner process is linked to caller" do
      # We can verify linking by checking Process.info
      pid = Sandbox.start_owner!()
      {:links, links} = Process.info(self(), :links)
      assert pid in links
      Sandbox.stop_owner(pid)
    end

    test "stop_owner/1 terminates the process" do
      pid = Sandbox.start_owner!()
      assert Process.alive?(pid)

      Sandbox.stop_owner(pid)
      Process.sleep(10)

      refute Process.alive?(pid)
    end

    test "stop_owner/1 cleans up sandbox tables" do
      pid = Sandbox.start_owner!()

      # Get the tables before stopping
      assert {:ok, _tables} = Sandbox.find_tables(pid)

      Sandbox.stop_owner(pid)

      # Tables should no longer be findable
      assert :not_found = Sandbox.find_tables(pid)
    end
  end

  describe "table resolution" do
    test "owner gets own tables" do
      assert :ok = Sandbox.checkout()
      buckets = Sandbox.get_buckets_table()
      objects = Sandbox.get_objects_table()

      assert is_reference(buckets)
      assert is_reference(objects)
    end

    test "allowed process gets owner's tables" do
      owner = Sandbox.start_owner!()

      # Get owner's tables
      {:ok, {owner_buckets, owner_objects}} = Sandbox.find_tables(owner)

      # Allow this process
      :ok = Sandbox.allow(owner, self())

      # This process should get owner's tables
      assert Sandbox.get_buckets_table() == owner_buckets
      assert Sandbox.get_objects_table() == owner_objects

      Sandbox.stop_owner(owner)
    end

    test "auto mode creates tables for unknown process" do
      Sandbox.mode(:auto)

      # A new process should get tables automatically
      task =
        Task.async(fn ->
          buckets = Sandbox.get_buckets_table()
          objects = Sandbox.get_objects_table()
          {buckets, objects}
        end)

      {buckets, objects} = Task.await(task)
      assert is_reference(buckets)
      assert is_reference(objects)
    end

    test "manual mode raises error for unknown process" do
      Sandbox.mode(:manual)

      # Use a task to get a fresh process
      task =
        Task.async(fn ->
          try do
            Sandbox.get_buckets_table()
            :no_error
          rescue
            e -> {:error, e}
          end
        end)

      result = Task.await(task)
      assert {:error, %RuntimeError{}} = result
    end

    test "shared mode uses shared owner's tables" do
      owner = Sandbox.start_owner!()
      {:ok, owner_tables} = Sandbox.find_tables(owner)

      Sandbox.mode({:shared, owner})

      # A new process should get shared owner's tables
      task =
        Task.async(fn ->
          Sandbox.find_tables(self())
        end)

      result = Task.await(task)
      assert {:ok, ^owner_tables} = result

      Sandbox.stop_owner(owner)
    end
  end

  describe "isolation" do
    test "each owner sees only its own buckets" do
      alias PS3.Storage.Memory

      owner1 = Sandbox.start_owner!()
      owner2 = Sandbox.start_owner!()

      # Owner 1 creates a bucket
      task1 =
        Task.async(fn ->
          Sandbox.allow(owner1, self())
          Memory.create_bucket("owner1-bucket")
          Memory.list_buckets()
        end)

      # Owner 2 creates a different bucket
      task2 =
        Task.async(fn ->
          Sandbox.allow(owner2, self())
          Memory.create_bucket("owner2-bucket")
          Memory.list_buckets()
        end)

      {:ok, buckets1} = Task.await(task1)
      {:ok, buckets2} = Task.await(task2)

      assert [%{name: "owner1-bucket"}] = buckets1
      assert [%{name: "owner2-bucket"}] = buckets2

      Sandbox.stop_owner(owner1)
      Sandbox.stop_owner(owner2)
    end
  end

  describe "encode_metadata/1 and decode_metadata/1" do
    test "round-trip encode/decode preserves pid" do
      pid = Sandbox.start_owner!()

      encoded = Sandbox.encode_metadata(pid)
      assert is_binary(encoded)

      decoded = Sandbox.decode_metadata(encoded)
      assert decoded == pid

      Sandbox.stop_owner(pid)
    end

    test "encoded value is URL-safe base64" do
      pid = Sandbox.start_owner!()

      encoded = Sandbox.encode_metadata(pid)
      # URL-safe base64 only contains: A-Za-z0-9_-
      assert encoded =~ ~r/^[A-Za-z0-9_=-]+$/

      Sandbox.stop_owner(pid)
    end
  end

  # Helper functions

  defp spawn_owner do
    caller = self()

    pid =
      spawn_link(fn ->
        Sandbox.checkout()
        send(caller, :ready)
        Process.sleep(:infinity)
      end)

    receive do
      :ready -> pid
    after
      1000 -> raise "Timeout waiting for owner to start"
    end
  end
end
