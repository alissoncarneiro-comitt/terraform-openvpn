output "public_ip" {
  description = "IP público fixo do servidor VPN"
  value       = aws_eip.vpn.public_ip
}
