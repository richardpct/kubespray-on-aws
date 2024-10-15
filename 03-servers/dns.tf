data "aws_route53_zone" "main" {
  name = var.my_domain
}

resource "aws_route53_record" "bastion" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "bastion"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.bastion.public_ip]
}

resource "aws_route53_record" "name" {
  for_each = local.record_dns
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = each.key
  type     = "CNAME"
  ttl      = 5

  weighted_routing_policy {
    weight = 10
  }

  set_identifier = each.key
  records        = [aws_lb.internet.dns_name]
}
