variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type — minimum t3.medium for k3s + ArgoCD + Prometheus (not free tier)"
  type        = string
  default     = "t3.medium"
  validation {
    condition     = contains(["t3.medium", "t3.large", "t2.medium"], var.instance_type)
    error_message = "Instance type must be at least t3.medium. t2.micro is not sufficient for this stack."
  }
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID for us-east-1 (update if changing region)"
  type        = string
  default     = "ami-0230bd60aa48260c6" # Amazon Linux 2023 us-east-1
}

variable "public_key" {
  description = "SSH public key content (ed25519) — passed via TF_VAR_public_key"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "project_name" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "k8s-platform-lab"
}
