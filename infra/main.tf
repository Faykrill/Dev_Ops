# Bucket для результата скрапинга и queue с заданиями.
# Имена совпадают с переменными Makefile и docker-compose.yaml.
resource "aws_s3_bucket" "results" {
  bucket        = var.results_bucket_name
  force_destroy = var.force_destroy_bucket
}

resource "aws_sqs_queue" "tasks" {
  name = var.tasks_queue_name
}
