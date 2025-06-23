variable "key_name" {
  description = "Nome do par de chaves SSH cadastrado na AWS"
  type        = string
}


variable "allowed_cidr" {
  description = "Seu IP público (ex: '203.0.113.45/32') para acesso SSH"
  type        = string
}

variable "subnet_id" {
  description = "ID da subnet onde a instância será provisionada"
  type        = string
}

variable "security_group_ids" {
  description = "Lista de Security Groups a serem associados à instância"
  type        = list(string)
}

variable "route53_zone_id" {
  description = "ID da zona DNS no Route53 onde os registros serão criados"
  type        = string
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
  default     = "SENHA_SEGURA"
}

variable "api_token" {
  description = "Token para autenticação com API Laravel"
  type        = string
  sensitive   = true
  default     = "TOKEN_DA_API"
}
