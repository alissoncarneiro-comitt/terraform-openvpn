data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


resource "aws_eip" "vpn_eip" {
  count = var.eip_allocation_id == null ? 1 : 0
}


resource "aws_eip_association" "vpn_eip_assoc" {
  count         = var.eip_allocation_id != null ? 1 : 0
  instance_id   = aws_instance.vpn_instance.id
  allocation_id = var.eip_allocation_id
}


resource "aws_instance" "vpn_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
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


}

