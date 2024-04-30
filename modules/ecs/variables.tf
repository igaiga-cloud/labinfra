variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "region" {
  description = "The AWS region."
  type        = string
}

variable "account_id" {
  description = "The AWS Account ID."
  type        = string
}