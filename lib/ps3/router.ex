defmodule PS3.Router do
  @moduledoc """
  Plug router for S3 API endpoints.

  This module implements the S3-compatible HTTP API. It is designed to be
  mounted in any Plug-compatible web server.

  ## Mounting Examples

  ### With Bandit

      children = [
        {Bandit, plug: PS3.Router, scheme: :http, port: 9000}
      ]

  ### With Cowboy

      children = [
        {Plug.Cowboy, scheme: :http, plug: PS3.Router, port: 9000}
      ]

  ### With Phoenix

  In your Phoenix router (`lib/your_app_web/router.ex`):

      scope "/" do
        forward "/s3", PS3.Router
      end

  Then access PS3 at `http://localhost:4000/s3/`

  ## Supported S3 Operations

  - List buckets: `GET /`
  - Create bucket: `PUT /{bucket}`
  - Delete bucket: `DELETE /{bucket}`
  - Head bucket: `HEAD /{bucket}`
  - List objects (v1 & v2): `GET /{bucket}`
  - Put object: `PUT /{bucket}/{key}`
  - Get object: `GET /{bucket}/{key}`
  - Head object: `HEAD /{bucket}/{key}`
  - Delete object: `DELETE /{bucket}/{key}`
  - Delete objects (batch): `POST /{bucket}?delete`
  - Copy object: `PUT /{dest_bucket}/{dest_key}` with `x-amz-copy-source` header
  """
  use Plug.Router

  # Allow HTTP handlers to access test sandbox tables via header
  plug(PS3.Plugs.SandboxAllowance)

  plug(Plug.Head)
  plug(:match)
  plug(:dispatch)

  # List all buckets: GET /
  get "/" do
    PS3.BucketHandler.list_buckets(conn)
  end

  # Bucket operations: /{bucket}
  get "/:bucket" do
    PS3.BucketHandler.list_objects(conn, bucket)
  end

  # Create a bucket: PUT /{bucket}
  put "/:bucket" do
    PS3.BucketHandler.create_bucket(conn, bucket)
  end

  # Delete a bucket: DELETE /{bucket}
  delete "/:bucket" do
    PS3.BucketHandler.delete_bucket(conn, bucket)
  end

  # Batch delete objects: POST /{bucket}?delete
  post "/:bucket" do
    PS3.ObjectHandler.delete_objects(conn, bucket)
  end

  # Get an object: GET /{bucket}/{key} (also handles HEAD via Plug.Head)
  get "/:bucket/*key" do
    key = Enum.join(key, "/")
    PS3.ObjectHandler.get_object(conn, bucket, key)
  end

  # Put an object: PUT /{bucket}/{key}
  put "/:bucket/*key" do
    key = Enum.join(key, "/")
    PS3.ObjectHandler.put_object(conn, bucket, key)
  end

  # Delete an object: DELETE /{bucket}/{key}
  delete "/:bucket/*key" do
    key = Enum.join(key, "/")
    PS3.ObjectHandler.delete_object(conn, bucket, key)
  end

  # Catch-all: 404 for unmatched routes
  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
