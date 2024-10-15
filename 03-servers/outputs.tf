output "kubernetes_api_internal" {
  value       = aws_lb.api_internal.dns_name
  description = "Kubernetes api internal"
}
