# S3x

A simple S3-compatible storage server written in pure Elixir, designed for development environments to avoid complex configuration.

## Features

- S3-compatible HTTP API
- Bucket operations (create, delete, list)
- Object operations (get, put, delete, list)
- Filesystem-based storage backend
- Simple configuration with sensible defaults

## Getting Started

### Installation

Install dependencies:

```sh
mix deps.get
```

### Running the Server

Start the server:

```sh
mix run --no-halt
```

The server will start on port 9000 by default. You can customize the port:

```sh
PORT=8000 mix run --no-halt
```

By default, data is stored in `./.s3` directory. You can customize the storage directory:

```sh
S3X_STORAGE_ROOT=/path/to/storage mix run --no-halt
```

### Usage Examples

Using the AWS CLI or any S3-compatible client:

```sh
# Configure endpoint
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
alias s3="aws s3 --endpoint-url http://localhost:9000"

# Create a bucket
s3 mb s3://my-bucket

# Upload a file
s3 cp myfile.txt s3://my-bucket/

# List objects
s3 ls s3://my-bucket/

# Download a file
s3 cp s3://my-bucket/myfile.txt downloaded.txt

# Delete an object
s3 rm s3://my-bucket/myfile.txt

# Delete a bucket
s3 rb s3://my-bucket
```

## Development

Run tests:

```sh
mix test
```

Run Credo for code quality:

```sh
mix credo
```

Format code:

```sh
mix format
```

