defmodule S3x.Router do
  @moduledoc """
  HTTP router for S3 API endpoints.
  """
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  # List all buckets: GET /
  get "/" do
    S3x.BucketHandler.list_buckets(conn)
  end

  # Bucket operations: /{bucket}
  get "/:bucket" do
    S3x.BucketHandler.list_objects(conn, bucket)
  end

  put "/:bucket" do
    S3x.BucketHandler.create_bucket(conn, bucket)
  end

  delete "/:bucket" do
    S3x.BucketHandler.delete_bucket(conn, bucket)
  end

  # Object operations: /{bucket}/{key}
  get "/:bucket/*key" do
    key = Enum.join(key, "/")
    S3x.ObjectHandler.get_object(conn, bucket, key)
  end

  put "/:bucket/*key" do
    key = Enum.join(key, "/")
    S3x.ObjectHandler.put_object(conn, bucket, key)
  end

  delete "/:bucket/*key" do
    key = Enum.join(key, "/")
    S3x.ObjectHandler.delete_object(conn, bucket, key)
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
