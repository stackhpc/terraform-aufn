variable "lab_flavor" {
  description = "Lab instance type"
  default     = "c1.small.x86"
}

variable "registry_flavor" {
  description = "Registry instance type"
  default     = "t1.small.x86"
}

variable "image_name" {
  description = "Lab software image base"
  default     = "CentOS8.2"
}

variable "lab_count" {
  description = "Number of labs"
  default     = "10"
}

variable "lab_net" {
  description = "Network for lab"
  default     = "demo-geneve"
}

variable "deploy_prefix" {
  description = "prefix to add to all hosts created under this deployment"
  default     = "kayobe"
}
