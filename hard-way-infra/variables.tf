variable "vpc_cidr" {
  type = string
  default = "10.1.0.0/16"
}

variable "subnet_cidr" {
  type = string
  default = "10.1.1.0/24"
}

variable "availability_zone" {
  type = string
  default = "ap-south-1a"
}