output "cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

# ELBのDNS名を出力
output "elb_dns_name" {
  value = aws_lb.elb.dns_name
}