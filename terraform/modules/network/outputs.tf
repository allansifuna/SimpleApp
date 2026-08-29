output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "public_subnet_ids" {
  description = "Both public subnets (primary + ALB-only secondary), for the ALB module"
  value       = [aws_subnet.public.id, aws_subnet.public_secondary.id]
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}
