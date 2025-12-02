defmodule S3x.ObjectHandler do
  @moduledoc """
  Handles S3 object operations.
  """
  import Plug.Conn

  @doc """
  Retrieves an object from a bucket.
  """
  def get_object(conn, bucket, key) do
    case S3x.Storage.get_object(bucket, key) do
      {:ok, data} ->
        conn
        |> put_resp_content_type("application/octet-stream")
        |> put_resp_header("content-length", "#{byte_size(data)}")
        |> send_resp(200, data)

      {:error, :no_such_key} ->
        xml = build_error_response("NoSuchKey", "The specified key does not exist")
        send_xml_error(conn, 404, xml)

      {:error, _reason} ->
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  @doc """
  Stores an object in a bucket.
  """
  def put_object(conn, bucket, key) do
    {:ok, body, conn} = read_body(conn)

    case S3x.Storage.put_object(bucket, key, body) do
      {:ok, _key} ->
        conn
        |> put_resp_header("etag", ~s("#{:crypto.hash(:md5, body) |> Base.encode16(case: :lower)}"))
        |> send_resp(200, "")

      {:error, :no_such_bucket} ->
        xml = build_error_response("NoSuchBucket", "The specified bucket does not exist")
        send_xml_error(conn, 404, xml)

      {:error, _reason} ->
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  @doc """
  Deletes an object from a bucket.
  """
  def delete_object(conn, bucket, key) do
    case S3x.Storage.delete_object(bucket, key) do
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
