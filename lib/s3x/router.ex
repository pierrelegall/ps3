defmodule S3x.Router do
  @moduledoc """
  Plug router for S3 API endpoints.

  This module implements the S3-compatible HTTP API. It is designed to be
  mounted in any Plug-compatible web server.

  ## Mounting Examples

  ### With Bandit

      children = [
        {Bandit, plug: S3x.Router, scheme: :http, port: 9000}
      ]

  ### With Cowboy

      children = [
        {Plug.Cowboy, scheme: :http, plug: S3x.Router, port: 9000}
      ]

  ### With Phoenix

  In your Phoenix router (`lib/your_app_web/router.ex`):

      scope "/" do
        forward "/s3", S3x.Router
      end

  Then access S3x at `http://localhost:4000/s3/`

  ## Supported S3 Operations

  - List buckets: `GET /`
  - Create bucket: `PUT /{bucket}`
  - Delete bucket: `DELETE /{bucket}`
  - List objects: `GET /{bucket}`
  - Put object: `PUT /{bucket}/{key}`
  - Get object: `GET /{bucket}/{key}`
  - Delete object: `DELETE /{bucket}/{key}`
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
