variable "aws_region" {
  description = "AWS region - must be us-east-1 or us-west-2 for Learner Labs"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Name for your SSH key in AWS"
  type        = string
  default     = "ecommerce-key"
}

variable "public_key_path" {
  description = "Path to your PUBLIC key file on your WSL computer"
  type        = string
  default     = "~/.ssh/devops-key.pub"
}
