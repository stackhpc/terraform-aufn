variable "lab_flavor" {
  description = "Lab instance type"
  default     = "baremetal"
}

variable "bastion_flavor" {
  description = "Bastion instance type"
  default     = "general.v1.tiny"
}

variable "registry_flavor" {
  description = "Registry instance type"
  default     = "general.v1.medium"
}

variable "registry_data_vol" {
  description = "Registry data volume in GB"
  default = "100"
}

variable "image_name" {
  description = "Lab software image base"
  default     = "CentOS-stream8"
}

variable "image_user" {
  description = "Lab software image cloud user"
  default     = "centos"
}

variable "lab_count" {
  description = "Number of labs"
  default     = "1"
}

variable "lab_data_vol" {
  description = "Lab data volume in GB"
  default = "200"
}

variable "lab_net_ipv4" {
  description = "Network for lab"
  default     = "aufn-ipv4-vlan"
}

variable "lab_prefix" {
  description = "prefix to add to all hosts created under this deployment"
  default     = "kayobe-skao"
}

