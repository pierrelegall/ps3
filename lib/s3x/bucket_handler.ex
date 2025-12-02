defmodule S3x.BucketHandler do
  @moduledoc """
  Handles S3 bucket operations.
  """
  import Plug.Conn

  @doc """
  Lists all buckets.
  """
  def list_buckets(conn) do
    S3x.Storage.init()

    case S3x.Storage.list_buckets() do
      {:ok, buckets} ->
        xml = build_list_buckets_response(buckets)

        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, xml)

      {:error, _reason} ->
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  @doc """
  Creates a new bucket.
  """
  def create_bucket(conn, bucket) do
    S3x.Storage.init()

    case S3x.Storage.create_bucket(bucket) do
      {:ok, _bucket} ->
        conn
        |> put_resp_header("location", "/#{bucket}")
        |> send_resp(200, "")

      {:error, :bucket_already_exists} ->
        xml =
          build_error_response("BucketAlreadyExists", "The requested bucket name already exists")

        send_xml_error(conn, 409, xml)

      {:error, _reason} ->
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  @doc """
  Deletes a bucket.
  """
  def delete_bucket(conn, bucket) do
    case S3x.Storage.delete_bucket(bucket) do
      :ok ->
        send_resp(conn, 204, "")

      {:error, :no_such_bucket} ->
        xml = build_error_response("NoSuchBucket", "The specified bucket does not exist")
        send_xml_error(conn, 404, xml)

      {:error, :bucket_not_empty} ->
        xml =
          build_error_response("BucketNotEmpty", "The bucket you tried to delete is not empty")

        send_xml_error(conn, 409, xml)

      {:error, _reason} ->
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  @doc """
  Lists objects in a bucket.
  """
  def list_objects(conn, bucket) do
    case S3x.Storage.list_objects(bucket) do
      {:ok, objects} ->
        xml = build_list_objects_response(bucket, objects)

        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, xml)

      {:error, :no_such_bucket} ->
        xml = build_error_response("NoSuchBucket", "The specified bucket does not exist")
        send_xml_error(conn, 404, xml)

      {:error, _reason} ->
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  # Private helpers

  defp build_list_buckets_response(buckets) do
    buckets_xml =
      Enum.map_join(buckets, "\n", fn bucket ->
        """
            <Bucket>
              <Name>#{bucket.name}</Name>
              <CreationDate>#{format_date(bucket.creation_date)}</CreationDate>
            </Bucket>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <Owner>
        <ID>s3x</ID>
        <DisplayName>s3x</DisplayName>
      </Owner>
      <Buckets>
    #{buckets_xml}
      </Buckets>
    </ListAllMyBucketsResult>
    """
  end

  defp build_list_objects_response(bucket, objects) do
    objects_xml =
      Enum.map_join(objects, "\n", fn object ->
        """
        <Contents>
          <Key>#{object.key}</Key>
          <LastModified>#{format_date(object.last_modified)}</LastModified>
          <Size>#{object.size}</Size>
        </Contents>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <Name>#{bucket}</Name>
    #{objects_xml}
    </ListBucketResult>
    """
  end

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

  defp format_date({{year, month, day}, {hour, minute, second}}) do
    "#{year}-#{pad(month)}-#{pad(day)}T#{pad(hour)}:#{pad(minute)}:#{pad(second)}.000Z"
  end

  defp pad(num) when num < 10, do: "0#{num}"
  defp pad(num), do: "#{num}"
end
