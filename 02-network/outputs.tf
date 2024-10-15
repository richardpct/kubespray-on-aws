output "vpc_id" {
  value       = aws_vpc.my_vpc.id
  description = "VPC ID"
}

output "subnet_public" {
  value       = aws_subnet.public[*].id
  description = "Subnet public"
}

output "subnet_private" {
  value       = aws_subnet.private[*].id
  description = "Subnet private"
}

output "aws_eip_nat_ip" {
  value       = aws_eip.nat[*].public_ip
  description = "eip IPs"
}
