variable "MyIpAddress" {
  description = "Enter the IP address that connects to the Bastion EC2"
  default = ["0.0.0.0/0"]
}

variable "EC2_Name" {
  description = "Set EC2 name"
  default = "seunghyeon-ec2"
}