locals {
  records = [
    {
      name = var.vpn_name
      type = "A"
    },
    {
      name = var.netdata_name
      type = "A"
    }
  ]
}

# cria um registro A para cada item em local.records
resource "aws_route53_record" "dns_records" {
  for_each = { for r in local.records : r.name => r }

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = var.ttl
  records = [var.public_ip]
}
