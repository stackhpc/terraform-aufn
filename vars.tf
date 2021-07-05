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

variable "image_name" {
  description = "Lab software image base"
  default     = "CentOS8.3-cloud"
}

variable "lab_count" {
  description = "Number of labs"
  default     = "2"
}

variable "lab_net_ipv6" {
  description = "Network for lab"
  default     = "stackhpc-ipv6-geneve"
}

variable "lab_net_ipv4" {
  description = "Network for lab"
  default     = "stackhpc-ipv4-vlan-v2"
}

variable "deploy_prefix" {
  description = "prefix to add to all hosts created under this deployment"
  default     = "kayobe"
}
