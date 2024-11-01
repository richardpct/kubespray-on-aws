terraform {
  backend "s3" {
  }
}

data "terraform_remote_state" "certificate" {
  backend = "s3"

  config = {
    bucket = var.bucket_certificate
    key    = var.key_certificate
    region = var.region
  }
}
