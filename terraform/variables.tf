variable "region" {
  description = "The AWS region to deploy the resources"
  type = string
  default = "ap-southeast-7"
}

variable "profile" {
  description = "The AWS profile to use for authentication"
  type = string
  default = null
}

variable "vpc_id" {
  description = "The ID of the VPC to deploy the resources in"
  type = string
  default = null
}

variable "my_ip" {
  description = "The public IP address of the local machine"
  type = string
}