# Провайдер указывает на локальное облако Floci, поэтому конфигурация
# одинаково разворачивается на любой машине без реального AWS.
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  s3_use_path_style = true 

  endpoints {
    s3  = var.floci_endpoint
    sqs = var.floci_endpoint
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}
