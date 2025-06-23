resource "aws_instance" "vpn_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t4g.medium"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.vpn_sg.id]
  key_name               = var.key_name
  ena_support            = true
  ebs_optimized          = true

  # Injeta as variáveis no script
  user_data = base64encode(templatefile("install_openvpn.sh", {
    admin_user    = var.admin_user
    ovpn_password = var.ovpn_password
    api_token     = var.api_token
  }))

  tags = {
    Name        = "vpn-server"
    Environment = "production"
    Project     = "o8partners"
  }

  depends_on = [
    aws_route53_record.vpn_dns,
    aws_route53_record.netdata_dns
  ]
}

module "ec2" {
  source         = "./modules/ec2"
  key_name       = var.key_name
  allowed_cidr   = var.allowed_cidr
  route53_zone_id = var.route53_zone_id
  admin_user     = var.admin_user
  ovpn_password  = var.ovpn_password
  api_token      = var.api_token
}