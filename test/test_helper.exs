ExUnit.start()

# Start a persistent process to own ETS tables for Memory backend tests
# This prevents tables from being deleted when individual test processes exit
defmodule S3x.Test.ETSOwner do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # Create ETS tables that will be used by Memory backend tests
    # These tables will persist for the entire test run
    :ets.new(:s3x_buckets, [:set, :public, :named_table])
    :ets.new(:s3x_objects, [:set, :public, :named_table])
    {:ok, :ok}
  end
end

{:ok, _pid} = S3x.Test.ETSOwner.start_link([])
