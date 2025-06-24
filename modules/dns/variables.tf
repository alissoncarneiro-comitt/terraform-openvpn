variable "zone_id" {
  type        = string
  description = "ID da Route53 Hosted Zone"
}

variable "public_ip" {
  type        = string
  description = "IP público da instância VPN"
}

variable "vpn_name" {
  type    = string
  default = "vpn"
}

variable "netdata_name" {
  type    = string
  default = "monitor.vpn"
}

variable "ttl" {
  type    = number
  default = 300
}
