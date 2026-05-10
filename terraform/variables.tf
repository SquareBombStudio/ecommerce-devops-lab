variable "aws_region" {
  description = "AWS region - must be us-east-1 or us-west-2 for Learner Labs"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Name of the EXISTING SSH key pair in AWS (must already be created in the console)"
  type        = string
  default     = "devops-key"
}
