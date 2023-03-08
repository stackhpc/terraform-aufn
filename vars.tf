variable "lab_flavor" {
  description = "Lab instance type"
  default     = "baremetal-32"
}

# Note: If using baremetals, this should be set to false.
# Can be set to true to give VMs more storage space.
variable "boot_labs_from_volume" {
  description = "Whether or not to boot labs from volume."
  default     = "false"
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

variable "image_id" {
  description = "Boot from volume requires ID of image"
}

variable "image_name" {
  description = "Lab software image base"
  default     = "CentOS-stream8"
}

variable "image_user" {
  description = "Lab software image cloud user"
  default     = "cloud-user"
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
  default     = "aufn"
}

variable "allocate_floating_ips" {
  description = "Whether or not floating ips should be allocated to lab instances and the registry"
  default     = "false"
}

# Remember to set a floating IP if you're using a bastion
variable "create_bastion" {
  description = "Whether or not to create a bastion instance"
  default     = "false"
}

variable "bastion_floating_ip" {
  description = "Bastion floating IP"
  default     = "0.0.0.0"
}