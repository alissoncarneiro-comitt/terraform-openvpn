variable "key_name" {
  description = "Nome do par de chaves SSH cadastrado na AWS"
  type        = string
  default     = "keyPair"

}

variable "instance_type" {
  description = "Instance Tyoe"
  type        = string
  default     = "t2.small"
}

variable "allowed_cidr" {
  description = "Seu IP público (ex: '203.0.113.45/32') para acesso SSH"
  type        = string
  default     = "172.31.0.0/16"
}

variable "subnet_id" {
  description = "ID da subnet onde a instância será provisionada"
  type        = string
  default     = "subnet-0225e34853be3d5aa"

}
variable "eip_allocation_id" {
  description = "ID do Elastic IP existente na AWS (opcional)"
  type        = string
  default     = null
}

variable "security_group_ids" {
  description = "Lista de Security Groups a serem associados à instância"
  type        = list(string)
  default     = ["sg-005c6d9bbdad744b6"]
}

variable "route53_zone_id" {
  description = "ID da zona DNS no Route53 onde os registros serão criados"
  type        = string
  default     = "Z05496661ET08XJQSBJW1"
}
variable "admin_user" {
  description = "Usuário administrador para acesso ao .ovpn e Netdata"
  type        = string
  default     = "admin"
}

variable "ovpn_password" {
  description = "Senha padrão para download do cliente .ovpn"
  type        = string
  sensitive   = true
  default     = "MinhaSenhaSuperSegura2025!"

}

variable "api_token" {
  description = "Token para autenticação com API Laravel"
  type        = string
  sensitive   = true
  default     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxxx"

}
