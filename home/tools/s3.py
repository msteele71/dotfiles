#! /usr/bin/env python3

import boto3
import argparse
from boto3.s3.transfer import TransferConfig
import os


def upload_to_s3(s3_client, config, file_name, bucket_name, object_name=None):
    if object_name is None:
        object_name = file_name

    try:
        s3_client.upload_file(file_name, bucket_name, object_name, Config=config)
        print(f"File '{file_name}' uploaded to '{bucket_name}/{object_name}'.")
    except Exception as e:
        print(f"Error uploading file: {e}")


def download_from_s3(s3_client, config, bucket_name, object_name, file_name):
    try:
        s3_client.download_file(bucket_name, object_name, file_name, Config=config)
        print(f"File '{object_name}' downloaded from '{bucket_name}' to '{file_name}'.")
    except Exception as e:
        print(f"Error downloading file: {e}")


def list_objects_in_s3(s3_client, bucket_name, prefix=None):
    try:
        response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
        if 'Contents' in response:
            for obj in response['Contents']:
                print(obj['Key'])
        else:
            print("No objects found.")
    except Exception as e:
        print(f"Error listing objects: {e}")

def _add_default_args(parser):
    parser.add_argument("--bucket", help="S3 bucket name")
    parser.add_argument("--region", default="us-west-2")

def main():
    parser = argparse.ArgumentParser(description="Upload or download files to/from an S3 bucket.")

    subparsers = parser.add_subparsers(dest="command", help="Commands: upload or download")

    upload_parser = subparsers.add_parser("upload", help="Upload a file to S3")
    upload_parser.add_argument("--file", help="Path to the file to upload")
    upload_parser.add_argument("--object", nargs='?', help="S3 object name (optional, defaults to the file name)")
    _add_default_args(upload_parser)

    download_parser = subparsers.add_parser("download", help="Download a file from S3")
    download_parser.add_argument("--object", help="S3 object name to download")
    download_parser.add_argument("--file", help="Path to save the downloaded file")
    _add_default_args(download_parser)

    list_parser = subparsers.add_parser("list", help="List objects in an S3 bucket")
    list_parser.add_argument("--prefix", nargs='?', default='', help="Prefix to filter objects (optional)")
    _add_default_args(list_parser)

    args = parser.parse_args()

    s3_client = boto3.client(
        's3'
    )

    config = TransferConfig(
        multipart_threshold=50 * 1024 * 1024,  # 50MB threshold for multipart upload
        multipart_chunksize=10 * 1024 * 1024,  # 10MB per chunk
        max_concurrency=5                     # Number of parallel threads
    )

    if args.command == "upload":
        upload_to_s3(s3_client, config, args.file, args.bucket, args.object)
    elif args.command == "download":
        download_from_s3(s3_client, config, args.bucket, args.object, args.file)
    elif args.command == "list":
        list_objects_in_s3(s3_client, args.bucket, args.prefix)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()