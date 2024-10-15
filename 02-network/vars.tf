variable "region" {
  type        = string
  description = "Region"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC cidr block"
  default     = "192.168.0.0/16"
}

variable "subnet_private" {
  type        = list(string)
  description = "Subnet private"
  default     = ["192.168.0.0/24", "192.168.1.0/24", "192.168.2.0/24"]
}

variable "subnet_public" {
  type        = list(string)
  description = "Public subnet"
  default     = ["192.168.3.0/24", "192.168.4.0/24", "192.168.5.0/24"]
}
