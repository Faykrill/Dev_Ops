output "results_bucket_name" {
  description = "Значение S3_BUCKET_NAME для скрапера."
  value       = aws_s3_bucket.results.bucket
}

output "results_bucket_arn" {
  description = "ARN bucketа с результатами."
  value       = aws_s3_bucket.results.arn
}

output "tasks_queue_url" {
  description = "Значение SQS_QUEUE_URL для контейнеров (через host.docker.internal)."
  value       = "${var.container_floci_endpoint}/${var.floci_account_id}/${aws_sqs_queue.tasks.name}"
}

output "tasks_queue_url_from_host" {
  description = "URL очереди в виде, доступном с хоста (для проверки через aws-cli)."
  value       = aws_sqs_queue.tasks.url
}
