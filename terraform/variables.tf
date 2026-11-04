variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "project" {
  type    = string
  default = "url-shortener"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "AyoLaww"
}

variable "link_ttl_days" {
  description = "How long a short link stays valid"
  type        = number
  default     = 90
}

variable "log_retention_days" {
  description = "CloudWatch log retention, keeps storage costs near zero"
  type        = number
  default     = 14
}