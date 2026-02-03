defmodule PS3.ObjectHandler do
  @moduledoc """
  Handles S3 object operations.
  """
  import Plug.Conn

  @doc """
  Retrieves an object from a bucket.
  """
  def get_object(conn, bucket, key) do
    case PS3.Storage.get_object(bucket, key) do
      {:ok, data} ->
        conn
        |> put_resp_content_type("application/octet-stream")
        |> put_resp_header("content-length", "#{byte_size(data)}")
        |> put_resp_header("content-encoding", "identity")
        |> send_resp(200, data)

      {:error, :no_such_key} ->
        xml = build_error_response("NoSuchKey", "The specified key does not exist")
        send_xml_error(conn, 404, xml)

      {:error, _reason} ->
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  @doc """
  Stores an object in a bucket, or copies from another location if
  the `x-amz-copy-source` header is present.
  """
  def put_object(conn, bucket, key) do
    case get_req_header(conn, "x-amz-copy-source") do
      [source] -> copy_object(conn, bucket, key, source)
      [] -> do_put_object(conn, bucket, key)
    end
  end

  defp do_put_object(conn, bucket, key) do
    {:ok, body, conn} = read_body(conn)

    case PS3.Storage.put_object(bucket, key, body) do
      {:ok, _key} ->
        conn
        |> put_resp_header(
          "etag",
          ~s("#{:crypto.hash(:md5, body) |> Base.encode16(case: :lower)}")
        )
        |> send_resp(200, "")

      {:error, :no_such_bucket} ->
        xml = build_error_response("NoSuchBucket", "The specified bucket does not exist")
        send_xml_error(conn, 404, xml)

      {:error, _reason} ->
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  defp copy_object(conn, dest_bucket, dest_key, source) do
    {src_bucket, src_key} = split_copy_source(source)

    case PS3.Storage.get_object(src_bucket, src_key) do
      {:ok, data} ->
        case PS3.Storage.put_object(dest_bucket, dest_key, data) do
          {:ok, _key} ->
            etag = :crypto.hash(:md5, data) |> Base.encode16(case: :lower)
            now = DateTime.utc_now() |> DateTime.to_iso8601()

            xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <CopyObjectResult>
              <ETag>"#{etag}"</ETag>
              <LastModified>#{now}</LastModified>
            </CopyObjectResult>
            """

            conn
            |> put_resp_content_type("application/xml")
            |> send_resp(200, xml)

          {:error, :no_such_bucket} ->
            xml = build_error_response("NoSuchBucket", "The specified bucket does not exist")
            send_xml_error(conn, 404, xml)

          {:error, _reason} ->
            send_resp(conn, 500, "Internal Server Error")
        end

      {:error, :no_such_key} ->
        xml = build_error_response("NoSuchKey", "The specified key does not exist")
        send_xml_error(conn, 404, xml)

      {:error, _reason} ->
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  defp split_copy_source(source) do
    source = String.trim_leading(source, "/")

    case String.split(source, "/", parts: 2) do
      [bucket, key] -> {bucket, key}
    end
  end

  @doc """
  Deletes multiple objects from a bucket (batch delete).
  """
  def delete_objects(conn, bucket) do
    {:ok, body, conn} = read_body(conn)

    keys =
      Regex.scan(~r/<Key>([^<]+)<\/Key>/, body)
      |> Enum.map(fn [_, key] -> key end)

    Enum.each(keys, fn key ->
      PS3.Storage.delete_object(bucket, key)
    end)

    deleted_xml =
      Enum.map_join(keys, "\n", fn key ->
        "<Deleted><Key>#{key}</Key></Deleted>"
      end)

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <DeleteResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
    #{deleted_xml}
    </DeleteResult>
    """

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  @doc """
  Deletes an object from a bucket.
  """
  def delete_object(conn, bucket, key) do
    case PS3.Storage.delete_object(bucket, key) do
      :ok ->
        send_resp(conn, 204, "")

      {:error, :no_such_key} ->
        send_resp(conn, 204, "")

      {:error, _reason} ->
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  # Private helpers

  defp build_error_response(code, message) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Error>
      <Code>#{code}</Code>
      <Message>#{message}</Message>
    </Error>
    """
  end

  defp send_xml_error(conn, status, xml) do
    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(status, xml)
  end
end
