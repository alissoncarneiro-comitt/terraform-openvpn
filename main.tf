module "ec2" {
  source             = "./modules/ec2"
  instance_type      = var.instance_type
  eip_allocation_id  = var.eip_allocation_id
  key_name           = var.key_name
  allowed_cidr       = var.allowed_cidr
  route53_zone_id    = var.route53_zone_id
  admin_user         = var.admin_user
  ovpn_password      = var.ovpn_password
  api_token          = var.api_token
  subnet_id          = var.subnet_id
  security_group_ids = var.security_group_ids
}


module "dns" {
  source       = "./modules/dns"
  zone_id      = var.route53_zone_id
  public_ip    = module.ec2.public_ip
  vpn_name     = "vpn"
  netdata_name = "monitor.vpn"
}
