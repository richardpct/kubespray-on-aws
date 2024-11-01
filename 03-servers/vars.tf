locals {
  distribution   = "ubuntu" // amazonlinux or ubuntu
  linux_user     = local.distribution == "ubuntu" ? "ubuntu" : "ec2-user"
  ubuntu_vers    = "20.04"
  archi          = "amd64" // amd64 or arm64
  kubespray_vers = "v2.23.1"
  ssh_port       = 22
  http_port      = 80
  https_port     = 443
  nfs_port       = 2049
  kube_api_port  = 6443
  hubble_port    = 4245
  nodeport_http  = 80
  nodeport_https = 443
  anywhere       = ["0.0.0.0/0"]
  bastion_price  = "0.005"
  bastion_min    = 1
  bastion_max    = 1
  master_price   = "0.01"
  master_min     = 3
  master_max     = 3
  worker_price   = "0.01"
  worker_min     = 3
  worker_max     = 3
  record_dns     = toset(["grafana", "vault", "www2", "argocd", "jfrog"])
}

variable "region" {
  type        = string
  description = "Region"
}

variable "bucket" {
  type        = string
  description = "Bucket"
}

variable "key_network" {
  type        = string
  description = "Network key"
}

variable "instance_type_bastion" {
  type        = string
  description = "instance type"
  default     = "t3a.micro"
}

variable "instance_type_master" {
  type        = string
  description = "instance type"
  default     = "t3a.small"
}

variable "instance_type_worker" {
  type        = string
  description = "instance type"
  default     = "t3a.small"
}

variable "root_size_master" {
  type        = number
  description = "instance master root size"
  default     = 12
}

variable "root_size_worker" {
  type        = number
  description = "instance worker root size"
  default     = 15
}

variable "longhorn_size_worker" {
  type        = number
  description = "instance worker longhorn size"
  default     = 15
}

variable "ssh_public_key" {
  type        = string
  description = "ssh public key"
}

variable "ssh_bastion_private_key" {
  type        = string
  description = "ssh bastion private key"
}

variable "ssh_nodes_public_key" {
  type        = string
  description = "ssh nodes public key"
}

variable "my_domain" {
  type        = string
  description = "domain name"
}

variable "my_ip_address" {
  type        = string
  description = "My IP address"
}
