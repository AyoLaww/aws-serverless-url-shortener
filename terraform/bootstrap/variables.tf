variable "aws_region" {
  description = "Region for the state bucket and the whole project"
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Project name, used in the bucket name and the Project tag"
  type        = string
  default     = "url-shortener"
}

variable "owner" {
  description = "Value for the Owner tag"
  type        = string
  default     = "AyoLaww"
}