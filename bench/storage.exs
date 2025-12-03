# Storage Backend Benchmark
#
# Run with: mix run bench/storage_benchmark.exs
#
# This benchmark compares the performance of the Filesystem and Memory storage backends.

# Setup for Filesystem backend
test_storage_root = "./bench_filesystem_data"
System.put_env("S3X_STORAGE_ROOT", test_storage_root)
File.rm_rf(test_storage_root)

alias S3x.Storage.{Filesystem, Memory}

# Initialize both backends
Filesystem.init()
Memory.init()

IO.puts("\n=== Storage Backend Benchmarks ===\n")

# Cleanup function for filesystem
cleanup_filesystem = fn ->
  File.rm_rf(test_storage_root)
  Filesystem.init()
end

# Cleanup function for memory
cleanup_memory = fn ->
  if :ets.whereis(:s3x_buckets) != :undefined do
    :ets.delete_all_objects(:s3x_buckets)
  end

  if :ets.whereis(:s3x_objects) != :undefined do
    :ets.delete_all_objects(:s3x_objects)
  end

  Memory.init()
end

# Benchmark: Create Bucket
IO.puts("Benchmarking: Create Bucket")

Benchee.run(
  %{
    "Filesystem" => fn i -> Filesystem.create_bucket("bucket-#{i}") end,
    "Memory" => fn i -> Memory.create_bucket("bucket-#{i}") end
  },
  before_scenario: fn _ ->
    cleanup_filesystem.()
    cleanup_memory.()
    0
  end,
  before_each: fn i -> i + 1 end,
  time: 5,
  memory_time: 2
)

# Benchmark: Put Object
IO.puts("\nBenchmarking: Put Object (1KB)")

cleanup_filesystem.()
cleanup_memory.()
Filesystem.create_bucket("benchmark")
Memory.create_bucket("benchmark")
data_1kb = :crypto.strong_rand_bytes(1024)

Benchee.run(
  %{
    "Filesystem" => fn i -> Filesystem.put_object("benchmark", "file-#{i}.txt", data_1kb) end,
    "Memory" => fn i -> Memory.put_object("benchmark", "file-#{i}.txt", data_1kb) end
  },
  before_scenario: fn _ -> 0 end,
  before_each: fn i -> i + 1 end,
  time: 5,
  memory_time: 2
)

# Benchmark: Get Object
IO.puts("\nBenchmarking: Get Object (1KB)")

cleanup_filesystem.()
cleanup_memory.()
Filesystem.create_bucket("benchmark")
Memory.create_bucket("benchmark")

# Pre-populate with 100 objects
for i <- 1..100 do
  Filesystem.put_object("benchmark", "file-#{i}.txt", data_1kb)
  Memory.put_object("benchmark", "file-#{i}.txt", data_1kb)
end

Benchee.run(
  %{
    "Filesystem" => fn -> Filesystem.get_object("benchmark", "file-500.txt") end,
    "Memory" => fn -> Memory.get_object("benchmark", "file-500.txt") end
  },
  time: 5,
  memory_time: 2
)

# Benchmark: List Objects
IO.puts("\nBenchmarking: List Objects (100 objects)")

Benchee.run(
  %{
    "Filesystem" => fn -> Filesystem.list_objects("benchmark") end,
    "Memory" => fn -> Memory.list_objects("benchmark") end
  },
  time: 5,
  memory_time: 2
)

# Benchmark: Delete Object
IO.puts("\nBenchmarking: Delete Object")

cleanup_filesystem.()
cleanup_memory.()
Filesystem.create_bucket("benchmark")
Memory.create_bucket("benchmark")

Benchee.run(
  %{
    "Filesystem" => fn i ->
      Filesystem.put_object("benchmark", "file-#{i}.txt", data_1kb)
      Filesystem.delete_object("benchmark", "file-#{i}.txt")
    end,
    "Memory" => fn i ->
      Memory.put_object("benchmark", "file-#{i}.txt", data_1kb)
      Memory.delete_object("benchmark", "file-#{i}.txt")
    end
  },
  before_scenario: fn _ -> 0 end,
  before_each: fn i -> i + 1 end,
  time: 5,
  memory_time: 2
)

# Benchmark: Many buckets
IO.puts("\nBenchmarking: Create 100 buckets")

Benchee.run(
  %{
    "Filesystem" => fn ->
      cleanup_filesystem.()

      for i <- 1..100 do
        Filesystem.create_bucket("bucket-#{i}")
      end
    end,
    "Memory" => fn ->
      cleanup_memory.()

      for i <- 1..100 do
        Memory.create_bucket("bucket-#{i}")
      end
    end
  },
  time: 10,
  warmup: 2
)

# Benchmark: Many objects
IO.puts("\nBenchmarking: Put 100 objects in one bucket")

Benchee.run(
  %{
    "Filesystem" => fn ->
      cleanup_filesystem.()
      Filesystem.create_bucket("benchmark")

      for i <- 1..100 do
        Filesystem.put_object("benchmark", "file-#{i}.txt", "content")
      end
    end,
    "Memory" => fn ->
      cleanup_memory.()
      Memory.create_bucket("benchmark")

      for i <- 1..100 do
        Memory.put_object("benchmark", "file-#{i}.txt", "content")
      end
    end
  },
  time: 10,
  warmup: 2
)

# Cleanup
File.rm_rf(test_storage_root)
IO.puts("\n=== Benchmarks Complete ===\n")
