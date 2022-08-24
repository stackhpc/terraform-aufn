variable "lab_flavor" {
  description = "Lab instance type"
  default     = "aufn"
}

variable "bastion_flavor" {
  description = "Bastion instance type"
  default     = "m1.tiny"
}

variable "registry_flavor" {
  description = "Registry instance type"
  default     = "m1.small"
}

variable "registry_data_vol" {
  description = "Registry data volume in GB"
  default = "100"
}

variable "image_name" {
  description = "Lab software image base"
  default     = "CentOS8-stream"
}

variable "image_user" {
  description = "Lab software image cloud user"
  default     = "centos"
}

variable "lab_count" {
  description = "Number of labs"
  default     = "10"
}

variable "lab_data_vol" {
  description = "Lab data volume in GB"
  default = "200"
}

variable "lab_net_ipv4" {
  description = "Network for lab"
  default     = "aufn"
}

variable "lab_prefix" {
  description = "prefix to add to all hosts created under this deployment"
  default     = "kayobe-mtc"
}

variable "lab_fip" {
  default     = "10.136.81.138"
}
