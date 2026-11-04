variable "aws_region" {
  description = "Условный region локального облака."
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "Доступ для Floci (не реальный ключ AWS)."
  type        = string
  default     = "test"
}

variable "aws_secret_key" {
  description = "Секрет для Floci (не реальный секрет AWS)."
  type        = string
  default     = "test"
  sensitive   = true
}

# Terraform запускается с хоста, поэтому localhost, а не host.docker.internal.
variable "floci_endpoint" {
  description = "URL Floci для Terraform."
  type        = string
  default     = "http://localhost:4566"
}

# Контейнеры достают тот же Floci по другому имени — оно и отдаётся в outputs,
# чтобы значения SQS_QUEUE_URL / S3_BUCKET_NAME не дублировались вручную.
variable "container_floci_endpoint" {
  description = "URL Floci, доступный изнутри контейнеров."
  type        = string
  default     = "http://host.docker.internal:4566"
}

variable "floci_account_id" {
  description = "Условный номер аккаунта Floci, часть URL очереди."
  type        = string
  default     = "000000000000"
}

variable "results_bucket_name" {
  description = "Имя S3 bucket для результата скрапинга."
  type        = string
  default     = "scraper-results-bucket"
}

variable "tasks_queue_name" {
  description = "Имя SQS queue с заданиями на скрапинг."
  type        = string
  default     = "scraper-tasks-queue"
}

variable "force_destroy_bucket" {
  description = "Разрешить destroy удалить bucket вместе с объектами внутри."
  type        = bool
  default     = true
}
