variable "pm_password" {
  sensitive = true
}

variable "target_node" {}
variable "template_name" {}
variable "instance_name" {}
variable "ip_address" {}
variable "gateway" {
  default = "192.168.1.1"
}
