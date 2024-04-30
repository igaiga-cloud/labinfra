terraform {
  backend "s3" {
    bucket = "terraform-vuln01-tfstate"  #S3バケット名を指定
    key    = "terraform.tfstate" # tfstate名を指定する
    region = "ap-northeast-1"
  }
}