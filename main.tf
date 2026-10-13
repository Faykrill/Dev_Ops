terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"
  endpoints {
    s3  = "http://localhost:4566"
    sqs = "http://localhost:4566"
  }
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

resource "aws_s3_bucket" "results" {
  bucket        = "scraper-results-bucket"
  force_destroy = true
}

resource "aws_sqs_queue" "tasks" {
  name = "scraper-tasks-queue"
}