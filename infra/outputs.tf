output "public_ip" {
  description = "Public IP of the EC2 instance — use this to SSH in and access services"
  value       = aws_instance.k8s.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.k8s.id
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i ~/.ssh/k8s-platform-lab-key ec2-user@${aws_instance.k8s.public_ip}"
}
