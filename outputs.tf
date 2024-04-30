output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "elb_dns_name" {
  value = module.ecs.elb_dns_name
}