locals {
  nodeport_http = 30080
}

variable "region" {
  type        = string
  description = "Region"
}

variable "bucket_certificate" {
  type        = string
  description = "Bucket"
}

variable "key_certificate" {
  type        = string
  description = "Certificate key"
}

variable "my_domain" {
  type        = string
  description = "domain name"
}
