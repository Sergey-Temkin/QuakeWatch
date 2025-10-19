output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "security_group_id" {
  value = aws_security_group.k3s_nodes.id
}

output "instance_profile_name" {
  value = length(aws_iam_instance_profile.ec2_profile) > 0 ? aws_iam_instance_profile.ec2_profile[0].name : null
}

output "k3s_server_public_ip" {
  value = aws_instance.k3s_server.public_ip
}
