# Set Backend
terraform {
  backend "s3" {
    bucket = "seunghyeon-test"
    key = "project/terraform.tfstate"
    region = "ap-northeast-2"
    encrypt = true
  }
}
