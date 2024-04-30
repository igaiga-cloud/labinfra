variable "region" {
  description = "AWS region"
  default     = "ap-northeast-1" #対象のリージョンを指定
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
  default     = "" #自身のアカウントIDを指定
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  default     = ""  # ここにテスト用のアクセスキーを入力
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  default     = ""  # ここにテスト用のシークレットキーを入力
}