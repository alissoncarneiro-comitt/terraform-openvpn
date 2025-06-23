module "ec2" {
  source           = "./modules/ec2"
  key_name         = var.key_name
  allowed_cidr     = var.allowed_cidr
  route53_zone_id  = var.route53_zone_id
  admin_user       = var.admin_user
  ovpn_password    = var.ovpn_password
  api_token        = var.api_token
}
