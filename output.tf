output "public_subnets" {
  value = aws_subnet.public.*.id
}

output "private_subnets" {
  value = aws_subnet.private.*.id
}

output "database_subnets" {
  value = aws_subnet.database.*
}

output "nat_gateway_ips" {
  value = aws_eip.nat.*.public_ip
}

output "vpc" {
  value = aws_vpc.main
}