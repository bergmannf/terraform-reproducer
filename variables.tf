variable "machines" {
  type    = number
  default = 2
}

variable "image_name" {
  type    = string
  default = "SLE-15-SP1-JeOS-GM"
}

variable "machine_size" {
  type    = string
  default = "m1.medium"
}

variable "external_net" {
  type    = string
  default = "floating"
}

variable "internal_net" {
  type    = string
  default = "terraform-test-net"
}

variable "internal_subnet" {
  type    = string
  default = "terraform-test-subnet"
}

variable "authorized_keys" {
  type    = list(string)
  default = [""]
}

variable "username" {
  type    = string
  default = "sles"
}
